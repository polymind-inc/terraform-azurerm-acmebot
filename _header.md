# Azure Acmebot

Deploys Azure Acmebot on Azure Functions Flex Consumption with managed-identity Storage access, optional private networking, App Service Authentication, and managed diagnostics.

## Usage

```hcl
module "acmebot" {
  source  = "polymind-inc/acmebot/azurerm"
  version = "~> 1.0"

  name      = "func-acmebot-module"
  parent_id = azurerm_resource_group.default.id
  location  = azurerm_resource_group.default.location
  tags = {
    workload = "acmebot"
  }

  enterprise_level_defaults_enabled = true

  acmebot = {
    version      = "5.0.1"
    mail_address = "YOUR-EMAIL-ADDRESS"
    vault_uri    = azurerm_key_vault.default.vault_uri

    dns_providers = {
      azure_dns = {
        subscription_id = data.azurerm_client_config.current.subscription_id
      }
    }
  }

  storage_account = {
    account_replication_type      = "ZRS"
    public_network_access_enabled = false

    private_endpoints = {
      blob = {
        subnet_resource_id = "/subscriptions/xxxx/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-storage-private-endpoints"
        subresource_name   = "blob"
        private_dns_zone_resource_ids = [
          "/subscriptions/xxxx/resourceGroups/rg-network/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
        ]
      }
      queue = {
        subnet_resource_id = "/subscriptions/xxxx/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-storage-private-endpoints"
        subresource_name   = "queue"
        private_dns_zone_resource_ids = [
          "/subscriptions/xxxx/resourceGroups/rg-network/providers/Microsoft.Network/privateDnsZones/privatelink.queue.core.windows.net"
        ]
      }
      table = {
        subnet_resource_id = "/subscriptions/xxxx/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-storage-private-endpoints"
        subresource_name   = "table"
        private_dns_zone_resource_ids = [
          "/subscriptions/xxxx/resourceGroups/rg-network/providers/Microsoft.Network/privateDnsZones/privatelink.table.core.windows.net"
        ]
      }
    }
  }

  log_analytics_workspace = {
    retention_in_days = 90
  }

  auth_settings = {
    enabled = true
    active_directory = {
      client_id            = azuread_application.default.client_id
      tenant_auth_endpoint = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0"
    }
  }

  auth_settings_client_secret = azuread_application_password.default.value

  virtual_network_subnet_id = "/subscriptions/xxxx/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-acmebot"

  site_config = {
    ip_restriction_default_action = "Deny"
    scm_use_main_ip_restriction   = true

    ip_restriction = [
      {
        name        = "Allow Azure Front Door"
        priority    = 100
        service_tag = "AzureFrontDoor.Backend"
        headers = {
          x_azure_fdid = ["00000000-0000-0000-0000-000000000000"]
        }
      }
    ]
  }

  lock = {
    kind = "CanNotDelete"
  }

  managed_identities = {
    system_assigned = true
  }

  # To make Acmebot and AzureWebJobsStorage use a user-assigned managed identity:
  # managed_identities = {
  #   system_assigned            = false
  #   user_assigned_resource_ids = [azurerm_user_assigned_identity.acmebot.id]
  # }
  # storage_managed_identity = {
  #   user_assigned_resource_id = azurerm_user_assigned_identity.acmebot.id
  # }
  # Add this to the acmebot object above:
  # managed_identity_client_id = azurerm_user_assigned_identity.acmebot.client_id

  private_endpoints = {
    primary = {
      subnet_resource_id = "/subscriptions/xxxx/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-private-endpoints"
      private_dns_zone_resource_ids = [
        "/subscriptions/xxxx/resourceGroups/rg-network/providers/Microsoft.Network/privateDnsZones/privatelink.azurewebsites.net"
      ]
    }
  }
}
```

## Notes

### Core Inputs

- `name` is the Function App name. It must be 2-32 characters; contain only letters, numbers, and hyphens; and start and end with a letter or number.
- `parent_id` is the AVM-aligned deployment scope input and must be the resource ID of an existing resource group.
- `acmebot.version` must be a Semantic Versioning 2.0.0 version, such as `5.0.1`, `5.0.1-beta.1`, or `5.0.1+build.5`.
- Acmebot workload settings are grouped under `acmebot`, including ACME account settings, Key Vault target, DNS provider configuration, webhook configuration, and External Account Binding.
- Acmebot deployment uses Azure Functions zip deploy. The package URI is built from `acmebot.version` as `https://stacmebotprod.blob.core.windows.net/acmebot/v<major>/<version>.zip`.

### Security and Identity

- Secret inputs are marked as sensitive, but they are still stored in Terraform state when used to configure the Function App.
- `AzureWebJobsStorage` and Flex Consumption package deployment storage use managed identity. By default this is the system-assigned identity; set `storage_managed_identity.user_assigned_resource_id` to use an attached user-assigned identity instead.
- The selected Storage identity receives Storage Account Contributor, Storage Blob Data Owner, Storage Queue Data Contributor, and Storage Table Data Contributor on the module-created Storage Account for identity-based host storage.
- To make Acmebot itself use a user-assigned managed identity for workload access, also attach it through `managed_identities.user_assigned_resource_ids` and set `acmebot.managed_identity_client_id`; the module maps it to `Acmebot__ManagedIdentityClientId`.
- Storage Account Shared Key authorization is disabled by default. Blob versioning, change feed, blob soft delete, container soft delete, Entra-first portal auth, and infrastructure encryption are enabled by default.

### Networking

- `enterprise_level_defaults_enabled` is enabled by default to disable public network access when unset, make SCM follow main IP restrictions, and enable route-all when VNET integration is configured.
- Storage data-plane endpoints for `AzureWebJobsStorage` and Flex Consumption package deployment storage are read from the deployed Storage Account so Azure public, China, and US Government endpoint suffixes are honored without hard-coding them. `acmebot.environment` defaults to `AzureCloud`; set it explicitly for sovereign cloud deployments.
- VNET integration uses the AVM App Service naming pattern `virtual_network_subnet_id`, and outbound route-all is configured with `site_config.vnet_route_all_enabled`.
- When `virtual_network_subnet_id` is set, `storage_account.private_endpoints` is required so Azure Functions can access its Storage Account through Private Endpoint. When Storage public access is disabled, `blob`, `queue`, and `table` private endpoints are required. The Flex Consumption VNET integration subnet cannot be shared with Private Endpoints, so provide a separate subnet.
- Storage Account Private Endpoints use the AVM private endpoint shape. Create entries for the storage subresources your Function App needs, typically `blob`, `queue`, and `table`, and set matching `private_dns_zone_resource_ids`.
- Private Endpoints default to the Function App `sites` subresource and manage a private DNS zone group when `private_dns_zone_resource_ids` is set.
- IP restrictions use AVM App Service-style `site_config.ip_restriction`, `site_config.scm_ip_restriction`, `site_config.ip_restriction_default_action`, `site_config.scm_ip_restriction_default_action`, and `site_config.scm_use_main_ip_restriction`.

### Operations

- Default diagnostic settings are created for the Function App and Storage Account resources to the module-managed or supplied Log Analytics workspace. Set `managed_diagnostic_settings_enabled = false` to manage diagnostics externally.
- Set `log_analytics_workspace.resource_id` and/or `application_insights.resource_id` to use existing monitoring resources instead of creating new ones. When Application Insights is supplied and managed diagnostics are disabled, the module does not create a Log Analytics workspace unless one is explicitly needed elsewhere.
- Child resources inherit `var.tags` by default, support child-specific tag overrides where Azure supports tags, and use CAF-aligned default name prefixes where applicable.
- Child resource settings can be overridden with `storage_account`, `deployment_container`, `service_plan`, `log_analytics_workspace`, and `application_insights`.
- AVM-style `diagnostic_settings`, `lock`, `managed_identities`, `role_assignments`, and `private_endpoints` inputs can apply diagnostic settings, resource locks, managed identities, RBAC assignments, and Private Endpoints to the Function App.
- This module uses an AzAPI-first implementation with AVM-aligned interface patterns and is published under the Terraform Registry `azurerm` namespace, but it is not an official Azure Verified Module.
