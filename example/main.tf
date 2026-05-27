provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

terraform {
  required_version = ">= 1.3.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.0"
    }
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
    redirect_uris = ["https://func-acmebot-${random_string.random.result}.azurewebsites.net/.auth/login/aad/callback"]

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

data "azurerm_client_config" "current" {
}

resource "azurerm_resource_group" "default" {
  name     = "rg-acmebot"
  location = "westus2"
}

resource "azurerm_key_vault" "default" {
  name                = "kv-acmebot-${random_string.random.result}"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location

  sku_name = "standard"

  rbac_authorization_enabled = true
  tenant_id                  = data.azurerm_client_config.current.tenant_id
}

resource "azurerm_role_assignment" "default" {
  scope                = azurerm_key_vault.default.id
  role_definition_name = "Key Vault Certificates Officer"
  principal_id         = module.acmebot.system_assigned_mi_principal_id
}

module "acmebot" {
  source = "../"

  name                   = "func-acmebot-${random_string.random.result}"
  resource_group_name    = azurerm_resource_group.default.name
  location               = azurerm_resource_group.default.location
  mail_address           = "YOUR-EMAIL-ADDRESS"
  vault_uri              = azurerm_key_vault.default.vault_uri
  acmebot_version        = "5.0.1"
  maximum_instance_count = 50
  instance_memory_in_mb  = 2048
  tags = {
    workload = "acmebot"
  }

  managed_identities = {
    system_assigned = true
  }

  # To use a user-assigned managed identity for Acmebot, assign Key Vault access
  # to that identity and pass both the AVM-style resource ID and Acmebot client ID.
  # managed_identities = {
  #   system_assigned            = false
  #   user_assigned_resource_ids = [azurerm_user_assigned_identity.acmebot.id]
  # }
  # acmebot_managed_identity_client_id = azurerm_user_assigned_identity.acmebot.client_id
  #
  # virtual_network_subnet_id = "/subscriptions/xxxx/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-acmebot"
  #
  # site_config = {
  #   vnet_route_all_enabled        = true
  #   ip_restriction_default_action = "Deny"
  #   scm_use_main_ip_restriction   = true
  #
  #   ip_restriction = [
  #     {
  #       name        = "Allow Azure Front Door"
  #       priority    = 100
  #       service_tag = "AzureFrontDoor.Backend"
  #       headers = {
  #         x_azure_fdid = ["00000000-0000-0000-0000-000000000000"]
  #       }
  #     }
  #   ]
  # }
  #
  # private_endpoints = {
  #   primary = {
  #     subnet_resource_id = "/subscriptions/xxxx/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-private-endpoints"
  #     private_dns_zone_resource_ids = [
  #       "/subscriptions/xxxx/resourceGroups/rg-network/providers/Microsoft.Network/privateDnsZones/privatelink.azurewebsites.net"
  #     ]
  #   }
  # }

  azure_dns = {
    subscription_id = data.azurerm_client_config.current.subscription_id
  }

  auth_settings = {
    enabled = true
    active_directory = {
      client_id            = azuread_application.default.client_id
      client_secret        = azuread_application_password.default.value
      tenant_auth_endpoint = "https://login.microsoftonline.com/${data.azuread_client_config.current.tenant_id}/v2.0"
    }
  }
}

output "system_assigned_mi_principal_id" {
  value = module.acmebot.system_assigned_mi_principal_id
}
