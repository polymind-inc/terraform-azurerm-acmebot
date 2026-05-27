# Azure Acmebot

Creates Acmebot on Azure Functions Flex Consumption.

## Usage

```hcl
module "acmebot" {
  source  = "polymind-inc/acmebot/azurerm"
  version = "~> 1.0"

  name                = "func-acmebot-module"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
  tags = {
    workload = "acmebot"
  }

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
    account_replication_type = "ZRS"
  }

  log_analytics_workspace = {
    retention_in_days = 90
  }

  auth_settings = {
    enabled = true
    active_directory = {
      client_id            = azuread_application.default.client_id
      client_secret        = azuread_application_password.default.value
      tenant_auth_endpoint = "https://sts.windows.net/${data.azurerm_client_config.current.tenant_id}/v2.0"
    }
  }

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

  # To make Acmebot use a user-assigned managed identity:
  # managed_identities = {
  #   system_assigned            = false
  #   user_assigned_resource_ids = [azurerm_user_assigned_identity.acmebot.id]
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

- `name` is the Function App name. It must be 2-32 characters; contain only letters, numbers, and hyphens; and start and end with a letter or number.
- `acmebot.version` must be a Semantic Versioning 2.0.0 version, such as `5.0.1`, `5.0.1-beta.1`, or `5.0.1+build.5`.
- Secret inputs are marked as sensitive, but they are still stored in Terraform state when used to configure the Function App.
- This module uses an azurerm-first implementation with AVM-aligned interface patterns, but it is not an official Azure Verified Module.
- AVM-style `diagnostic_settings`, `lock`, `managed_identities`, `role_assignments`, and `private_endpoints` inputs can apply diagnostic settings, resource locks, managed identities, RBAC assignments, and Private Endpoints to the Function App.
- Acmebot workload settings are grouped under `acmebot`, including ACME account settings, Key Vault target, DNS provider configuration, webhook configuration, and External Account Binding.
- Acmebot requires either `managed_identities.system_assigned = true` or a user-assigned managed identity. To use a user-assigned managed identity, attach it through `managed_identities.user_assigned_resource_ids` and set `acmebot.managed_identity_client_id`; the module maps it to `Acmebot__ManagedIdentityClientId`.
- Child resources inherit `var.tags` by default, support child-specific tag overrides where Azure supports tags, and use CAF-aligned default name prefixes where applicable.
- Child resource settings can be overridden with `storage_account`, `deployment_container`, `service_plan`, `log_analytics_workspace`, and `application_insights`.
- VNET integration uses the AVM App Service naming pattern `virtual_network_subnet_id`, and outbound route-all is configured with `site_config.vnet_route_all_enabled`.
- IP restrictions use AVM App Service-style `site_config.ip_restriction`, `site_config.scm_ip_restriction`, `site_config.ip_restriction_default_action`, `site_config.scm_ip_restriction_default_action`, and `site_config.scm_use_main_ip_restriction`.
- Private Endpoints default to the Function App `sites` subresource and manage a private DNS zone group when `private_dns_zone_resource_ids` is set.
- Acmebot deployment uses Azure Functions zip deploy. The package URI is built from `acmebot.version` as `https://stacmebotprod.blob.core.windows.net/acmebot/v<major>/<version>.zip`.
