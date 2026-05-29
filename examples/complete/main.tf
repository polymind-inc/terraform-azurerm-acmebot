locals {
  function_app_name = "func-acmebot-${random_string.random.result}"

  tags = {
    workload    = "acmebot"
    environment = "production"
  }

  # Private DNS zones keyed by the private endpoint they back. The first four are
  # passed to the module; "vault" backs the example-managed Key Vault endpoint.
  private_dns_zones = {
    sites = "privatelink.azurewebsites.net"
    blob  = "privatelink.blob.core.windows.net"
    queue = "privatelink.queue.core.windows.net"
    table = "privatelink.table.core.windows.net"
    vault = "privatelink.vaultcore.azure.net"
  }
}

resource "random_string" "random" {
  length  = 4
  lower   = true
  upper   = false
  special = false
}

resource "random_uuid" "user_impersonation" {}

resource "random_uuid" "app_role_issue" {}

resource "random_uuid" "app_role_revoke" {}

resource "time_rotating" "default" {
  rotation_days = 180
}

data "azuread_client_config" "current" {}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "default" {
  name     = "rg-acmebot-complete"
  location = "eastus2"
  tags     = local.tags
}

# User-assigned identity shared by the Function App for both the Acmebot workload
# (Key Vault access) and AzureWebJobsStorage, so RBAC can be granted up front.
resource "azurerm_user_assigned_identity" "acmebot" {
  name                = "id-acmebot-${random_string.random.result}"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
  tags                = local.tags
}

# Microsoft Entra application backing App Service Authentication.
resource "azuread_application" "default" {
  display_name    = "Acmebot ${random_string.random.result}"
  identifier_uris = ["api://acmebot-${random_string.random.result}"]
  owners          = [data.azuread_client_config.current.object_id]

  api {
    requested_access_token_version = 2

    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to access Acmebot on behalf of the signed-in user."
      admin_consent_display_name = "Access Acmebot"
      enabled                    = true
      id                         = random_uuid.user_impersonation.result
      type                       = "User"
      user_consent_description   = "Allow the application to access Acmebot on your behalf."
      user_consent_display_name  = "Access Acmebot"
      value                      = "user_impersonation"
    }
  }

  app_role {
    allowed_member_types = ["User", "Application"]
    description          = "Allow new and renew certificate"
    display_name         = "Acmebot.IssueCertificate"
    enabled              = true
    value                = "Acmebot.IssueCertificate"
    id                   = random_uuid.app_role_issue.result
  }

  app_role {
    allowed_member_types = ["User", "Application"]
    description          = "Allow revoke certificate"
    display_name         = "Acmebot.RevokeCertificate"
    enabled              = true
    value                = "Acmebot.RevokeCertificate"
    id                   = random_uuid.app_role_revoke.result
  }

  web {
    redirect_uris = ["https://${local.function_app_name}.azurewebsites.net/.auth/login/aad/callback"]

    implicit_grant {
      access_token_issuance_enabled = false
      id_token_issuance_enabled     = true
    }
  }
}

resource "azuread_service_principal" "default" {
  client_id = azuread_application.default.client_id
  owners    = [data.azuread_client_config.current.object_id]

  app_role_assignment_required = false
}

resource "azuread_application_password" "default" {
  application_id = azuread_application.default.id
  end_date       = timeadd(timestamp(), "8760h")

  rotate_when_changed = {
    rotation = time_rotating.default.id
  }

  lifecycle {
    create_before_destroy = true

    ignore_changes = [
      end_date
    ]
  }
}

# Key Vault holding issued certificates. Public network access is disabled and the
# vault is reached privately through the endpoint below.
resource "azurerm_key_vault" "default" {
  name                          = "kv-acmebot-${random_string.random.result}"
  resource_group_name           = azurerm_resource_group.default.name
  location                      = azurerm_resource_group.default.location
  sku_name                      = "standard"
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  rbac_authorization_enabled    = true
  public_network_access_enabled = false
  tags                          = local.tags

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

# Acmebot uses the user-assigned identity to issue and store certificates.
resource "azurerm_role_assignment" "keyvault_certificates_officer" {
  scope                            = azurerm_key_vault.default.id
  role_definition_name             = "Key Vault Certificates Officer"
  principal_id                     = azurerm_user_assigned_identity.acmebot.principal_id
  skip_service_principal_aad_check = true
}

resource "azurerm_private_endpoint" "keyvault" {
  name                = "pep-kv-acmebot-${random_string.random.result}"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-kv-acmebot"
    private_connection_resource_id = azurerm_key_vault.default.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.default["vault"].id]
  }
}

module "acmebot" {
  source = "../../"

  name                          = local.function_app_name
  parent_id                     = azurerm_resource_group.default.id
  location                      = azurerm_resource_group.default.location
  maximum_instance_count        = 100
  instance_memory_in_mb         = 2048
  public_network_access_enabled = false
  tags                          = local.tags

  acmebot = {
    version      = "5.0.1"
    mail_address = "admin@example.com"
    vault_uri    = azurerm_key_vault.default.vault_uri

    # Acmebot authenticates to Key Vault and Azure DNS with the user-assigned identity.
    managed_identity_client_id = azurerm_user_assigned_identity.acmebot.client_id

    dns_providers = {
      azure_dns = {
        subscription_id = data.azurerm_client_config.current.subscription_id
      }
    }
  }

  # Disable the system-assigned identity and route both the Acmebot workload and
  # AzureWebJobsStorage through the attached user-assigned identity.
  managed_identities = {
    system_assigned            = false
    user_assigned_resource_ids = [azurerm_user_assigned_identity.acmebot.id]
  }

  storage_managed_identity = {
    user_assigned_resource_id = azurerm_user_assigned_identity.acmebot.id
  }

  # VNET integration for outbound traffic. The Function App reaches its Storage
  # Account exclusively through the private endpoints below.
  virtual_network_subnet_id = azurerm_subnet.functions.id

  storage_account = {
    account_replication_type      = "ZRS"
    public_network_access_enabled = false

    private_endpoints = {
      blob = {
        subnet_resource_id            = azurerm_subnet.private_endpoints.id
        subresource_name              = "blob"
        private_dns_zone_resource_ids = [azurerm_private_dns_zone.default["blob"].id]
      }
      queue = {
        subnet_resource_id            = azurerm_subnet.private_endpoints.id
        subresource_name              = "queue"
        private_dns_zone_resource_ids = [azurerm_private_dns_zone.default["queue"].id]
      }
      table = {
        subnet_resource_id            = azurerm_subnet.private_endpoints.id
        subresource_name              = "table"
        private_dns_zone_resource_ids = [azurerm_private_dns_zone.default["table"].id]
      }
    }
  }

  # Private ingress for the Function App. With public access disabled, this is the
  # only inbound path.
  private_endpoints = {
    sites = {
      subnet_resource_id            = azurerm_subnet.private_endpoints.id
      private_dns_zone_resource_ids = [azurerm_private_dns_zone.default["sites"].id]
    }
  }

  site_config = {
    vnet_route_all_enabled = true
  }

  log_analytics_workspace = {
    retention_in_days = 90
  }

  lock = {
    kind = "CanNotDelete"
  }

  auth_settings = {
    enabled = true
    active_directory = {
      client_id            = azuread_application.default.client_id
      tenant_auth_endpoint = "https://login.microsoftonline.com/${data.azuread_client_config.current.tenant_id}/v2.0"
    }
  }

  auth_settings_client_secret = azuread_application_password.default.value

  # Ensure private DNS resolution is in place before the Function App is deployed
  # so it can reach Storage and Key Vault through their private endpoints.
  depends_on = [
    azurerm_private_dns_zone_virtual_network_link.default,
    azurerm_role_assignment.keyvault_certificates_officer,
    azurerm_private_endpoint.keyvault,
  ]
}
