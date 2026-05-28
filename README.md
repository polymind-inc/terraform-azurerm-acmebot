<!-- BEGIN_TF_DOCS -->
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
- When `virtual_network_subnet_id` is set, `storage_account.private_endpoints` is required so Azure Functions can access its Storage Account through Private Endpoint. The Flex Consumption VNET integration subnet cannot be shared with Private Endpoints, so provide a separate subnet.
- Storage Account Private Endpoints use the AVM private endpoint shape. Create entries for the storage subresources your Function App needs, typically `blob`, `queue`, and `table`, and set matching `private_dns_zone_resource_ids`.
- IP restrictions use AVM App Service-style `site_config.ip_restriction`, `site_config.scm_ip_restriction`, `site_config.ip_restriction_default_action`, `site_config.scm_ip_restriction_default_action`, and `site_config.scm_use_main_ip_restriction`.
- Private Endpoints default to the Function App `sites` subresource and manage a private DNS zone group when `private_dns_zone_resource_ids` is set.
- Acmebot deployment uses Azure Functions zip deploy. The package URI is built from `acmebot.version` as `https://stacmebotprod.blob.core.windows.net/acmebot/v<major>/<version>.zip`.

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.3.0, < 2.0.0)

- <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) (~> 2.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~> 4.0)

- <a name="requirement_random"></a> [random](#requirement\_random) (~> 3.0)

## Providers

The following providers are used by this module:

- <a name="provider_azapi"></a> [azapi](#provider\_azapi) (~> 2.0)

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (~> 4.0)

- <a name="provider_random"></a> [random](#provider\_random) (~> 3.0)

## Resources

The following resources are used by this module:

- [azapi_resource.deployment](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) (resource)
- [azurerm_application_insights.insights](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/application_insights) (resource)
- [azurerm_function_app_flex_consumption.function](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/function_app_flex_consumption) (resource)
- [azurerm_log_analytics_workspace.workspace](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace) (resource)
- [azurerm_management_lock.function_app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) (resource)
- [azurerm_management_lock.private_endpoint](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) (resource)
- [azurerm_management_lock.storage_account_private_endpoint](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) (resource)
- [azurerm_monitor_diagnostic_setting.function_app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) (resource)
- [azurerm_private_endpoint.function_app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) (resource)
- [azurerm_private_endpoint.function_app_unmanaged_dns_zone_groups](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) (resource)
- [azurerm_private_endpoint.storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) (resource)
- [azurerm_private_endpoint.storage_unmanaged_dns_zone_groups](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) (resource)
- [azurerm_private_endpoint_application_security_group_association.function_app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint_application_security_group_association) (resource)
- [azurerm_private_endpoint_application_security_group_association.storage_account](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint_application_security_group_association) (resource)
- [azurerm_role_assignment.function_app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) (resource)
- [azurerm_role_assignment.private_endpoint](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) (resource)
- [azurerm_role_assignment.storage_account_private_endpoint](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) (resource)
- [azurerm_service_plan.serverfarm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan) (resource)
- [azurerm_storage_account.storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) (resource)
- [azurerm_storage_container.deployment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) (resource)
- [random_string.deployment_container_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) (resource)
- [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) (data source)
- [azurerm_function_app_host_keys.function](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/function_app_host_keys) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_acmebot"></a> [acmebot](#input\_acmebot)

Description: Controls Acmebot workload configuration. This object is sensitive because DNS provider credentials, webhook URLs, and external account binding secrets are passed to the Function App as application settings and stored in Terraform state.

- `version` - (Required) The Acmebot package version to deploy. Must be a Semantic Versioning 2.0.0 version, such as `5.0.1`, `5.0.1-beta.1`, or `5.0.1+build.5`.
- `mail_address` - (Required) The email address for the ACME account.
- `vault_uri` - (Required) The Key Vault URI where issued certificates are stored.
- `acme_endpoint` - (Optional) The certification authority ACME endpoint. Defaults to Let's Encrypt production.
- `environment` - (Optional) The Azure environment name. Defaults to `AzureCloud`.
- `webhook_url` - (Optional) The webhook URL where Acmebot sends notifications.
- `mitigate_chain_order` - (Optional) Whether to mitigate certificate chain ordering issues that occur with some services. Defaults to `false`.
- `app_role_required` - (Optional) Whether additional app role assignment is required during Microsoft Entra authentication. Defaults to `false`.
- `managed_identity_client_id` - (Optional) The client ID of the user-assigned managed identity Acmebot should use. Set this when `managed_identities.system_assigned` is `false`.
- `external_account_binding` - (Optional) External Account Binding settings for ACME providers that require account binding.
- `dns_providers` - (Optional) DNS provider settings for Acmebot. Supported providers are `azure_dns`, `azure_private_dns`, `cloudflare`, `custom_dns`, `dns_made_easy`, `gandi`, `go_daddy`, `google_dns`, `route_53`, and `trans_ip`.

Type:

```hcl
object({
    version                    = string
    mail_address               = string
    vault_uri                  = string
    acme_endpoint              = optional(string, "https://acme-v02.api.letsencrypt.org/directory")
    environment                = optional(string, "AzureCloud")
    webhook_url                = optional(string, null)
    mitigate_chain_order       = optional(bool, false)
    app_role_required          = optional(bool, false)
    managed_identity_client_id = optional(string, null)
    external_account_binding = optional(object({
      key_id    = string
      hmac_key  = string
      algorithm = string
    }), null)
    dns_providers = optional(object({
      azure_dns = optional(object({
        subscription_id = string
      }), null)
      azure_private_dns = optional(object({
        subscription_id = string
      }), null)
      cloudflare = optional(object({
        api_token = string
      }), null)
      custom_dns = optional(object({
        endpoint            = string
        api_key             = string
        api_key_header_name = string
        propagation_seconds = number
      }), null)
      dns_made_easy = optional(object({
        api_key    = string
        secret_key = string
      }), null)
      gandi = optional(object({
        api_key = string
      }), null)
      go_daddy = optional(object({
        api_key    = string
        api_secret = string
      }), null)
      google_dns = optional(object({
        key_file64 = string
      }), null)
      route_53 = optional(object({
        access_key = string
        secret_key = string
        region     = string
      }), null)
      trans_ip = optional(object({
        customer_name    = string
        private_key_name = string
      }), null)
    }), {})
  })
```

### <a name="input_location"></a> [location](#input\_location)

Description: Azure region to create resources.

Type: `string`

### <a name="input_name"></a> [name](#input\_name)

Description: The name of the Function App.

Type: `string`

### <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name)

Description: Resource group name to be added.

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_additional_app_settings"></a> [additional\_app\_settings](#input\_additional\_app\_settings)

Description: Additional application settings to set on the Function App. Keys prefixed with `Acmebot__`, keys prefixed with `Acmebot:`, and `MICROSOFT_PROVIDER_AUTHENTICATION_SECRET` are reserved by this module.

Type: `map(string)`

Default: `{}`

### <a name="input_application_insights"></a> [application\_insights](#input\_application\_insights)

Description: Controls the Application Insights component connected to the Function App.

- `name` - (Optional) The name of the Application Insights component. When unset, the module generates a CAF-aligned name using the `appi` prefix.
- `tags` - (Optional) Tags to apply to the Application Insights component. When unset, `var.tags` is inherited.

Type:

```hcl
object({
    name = optional(string, null)
    tags = optional(map(string), null)
  })
```

Default: `{}`

### <a name="input_auth_settings"></a> [auth\_settings](#input\_auth\_settings)

Description: Controls App Service Authentication for the Function App.

- `enabled` - (Required) Whether App Service Authentication is enabled.
- `active_directory.client_id` - (Required) The Microsoft Entra application client ID.
- `active_directory.client_secret` - (Required) The Microsoft Entra application client secret. This value is stored in Terraform state.
- `active_directory.tenant_auth_endpoint` - (Required) The tenant-specific Microsoft Entra authorization endpoint.

Type:

```hcl
object({
    enabled = bool
    active_directory = object({
      client_id            = string
      client_secret        = string
      tenant_auth_endpoint = string
    })
  })
```

Default: `null`

### <a name="input_deployment_container"></a> [deployment\_container](#input\_deployment\_container)

Description: Controls the Storage Container used by the Function App deployment package.

- `name` - (Optional) The name of the Storage Container. When unset, the module generates a CAF-aligned name with a random suffix to avoid collisions.

Type:

```hcl
object({
    name = optional(string, null)
  })
```

Default: `{}`

### <a name="input_diagnostic_settings"></a> [diagnostic\_settings](#input\_diagnostic\_settings)

Description: A map of diagnostic settings to create on the Function App. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time.

- `name` - (Optional) The name of the diagnostic setting. One will be generated if not set.
- `log_categories` - (Optional) A set of log categories to send to the destination.
- `log_groups` - (Optional) A set of log category groups to send to the destination. Defaults to `["allLogs"]`.
- `metric_categories` - (Optional) A set of metric categories to send to the destination. Defaults to `["AllMetrics"]`.
- `log_analytics_destination_type` - (Optional) The destination table type for Log Analytics. Possible values are `Dedicated` and `AzureDiagnostics`. Defaults to `Dedicated`.
- `workspace_resource_id` - (Optional) The resource ID of the Log Analytics workspace destination.
- `storage_account_resource_id` - (Optional) The resource ID of the Storage Account destination.
- `event_hub_authorization_rule_resource_id` - (Optional) The resource ID of the Event Hub authorization rule destination.
- `event_hub_name` - (Optional) The Event Hub name. When unset, the default Event Hub is used.
- `marketplace_partner_resource_id` - (Optional) The full ARM resource ID of the Marketplace partner destination.

Type:

```hcl
map(object({
    name                                     = optional(string, null)
    log_categories                           = optional(set(string), [])
    log_groups                               = optional(set(string), ["allLogs"])
    metric_categories                        = optional(set(string), ["AllMetrics"])
    log_analytics_destination_type           = optional(string, "Dedicated")
    workspace_resource_id                    = optional(string, null)
    storage_account_resource_id              = optional(string, null)
    event_hub_authorization_rule_resource_id = optional(string, null)
    event_hub_name                           = optional(string, null)
    marketplace_partner_resource_id          = optional(string, null)
  }))
```

Default: `{}`

### <a name="input_export_api_key"></a> [export\_api\_key](#input\_export\_api\_key)

Description: Whether to read and export the default function host key as output.

Type: `bool`

Default: `false`

### <a name="input_instance_memory_in_mb"></a> [instance\_memory\_in\_mb](#input\_instance\_memory\_in\_mb)

Description: Optional memory size in MB for Flex Consumption instances. Supported values are 512, 2048, and 4096.

Type: `number`

Default: `null`

### <a name="input_lock"></a> [lock](#input\_lock)

Description: Controls the Resource Lock configuration for the Function App.

- `kind` - (Required) The lock kind. Possible values are `CanNotDelete` and `ReadOnly`.
- `name` - (Optional) The lock name. If not specified, a name will be generated based on the `kind` value.

Type:

```hcl
object({
    kind = string
    name = optional(string, null)
  })
```

Default: `null`

### <a name="input_log_analytics_workspace"></a> [log\_analytics\_workspace](#input\_log\_analytics\_workspace)

Description: Controls the Log Analytics workspace used by Application Insights.

- `name` - (Optional) The name of the Log Analytics workspace. When unset, the module generates a CAF-aligned name using the `log` prefix.
- `retention_in_days` - (Optional) The workspace retention period in days. Defaults to `30`.
- `tags` - (Optional) Tags to apply to the Log Analytics workspace. When unset, `var.tags` is inherited.

Type:

```hcl
object({
    name              = optional(string, null)
    retention_in_days = optional(number, 30)
    tags              = optional(map(string), null)
  })
```

Default: `{}`

### <a name="input_managed_identities"></a> [managed\_identities](#input\_managed\_identities)

Description: Controls the Managed Identity configuration on the Function App. Acmebot requires either a system-assigned managed identity or a user-assigned managed identity with `acmebot.managed_identity_client_id`.

- `system_assigned` - (Optional) Whether to enable a system-assigned managed identity. Defaults to `false`.
- `user_assigned_resource_ids` - (Optional) A set of user-assigned managed identity resource IDs to attach to the Function App.

Type:

```hcl
object({
    system_assigned            = optional(bool, false)
    user_assigned_resource_ids = optional(set(string), [])
  })
```

Default: `{}`

### <a name="input_maximum_instance_count"></a> [maximum\_instance\_count](#input\_maximum\_instance\_count)

Description: Optional maximum scale-out instance count for the Function App.

Type: `number`

Default: `null`

### <a name="input_private_endpoints"></a> [private\_endpoints](#input\_private\_endpoints)

Description: A map of private endpoints to create for the Function App. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time.

- `name` - (Optional) The name of the private endpoint. One will be generated if not set.
- `subnet_resource_id` - (Required) The resource ID of the subnet where the private endpoint will be created.
- `subresource_name` - (Optional) The Function App subresource name. Defaults to `sites`.
- `private_dns_zone_group_name` - (Optional) The private DNS zone group name. Defaults to `default`.
- `private_dns_zone_resource_ids` - (Optional) A set of private DNS zone resource IDs to associate with the private endpoint.
- `application_security_group_associations` - (Optional) A map of application security group resource IDs to associate with the private endpoint.
- `private_service_connection_name` - (Optional) The private service connection name. One will be generated if not set.
- `network_interface_name` - (Optional) The private endpoint network interface name.
- `location` - (Optional) The private endpoint location. Defaults to `var.location`.
- `resource_group_name` - (Optional) The private endpoint resource group name. Defaults to `var.resource_group_name`.
- `inherit_lock` - (Optional) Whether this private endpoint inherits `var.lock` when no endpoint-specific lock is set. Defaults to `true`.
- `lock` - (Optional) The lock to apply to this private endpoint.
- `tags` - (Optional) Tags to apply to this private endpoint. When unset, `var.tags` is inherited.
- `ip_configurations` - (Optional) A map of static IP configurations for the private endpoint.
- `role_assignments` - (Optional) A map of role assignments to create on this private endpoint.

Type:

```hcl
map(object({
    name                                    = optional(string, null)
    subnet_resource_id                      = string
    subresource_name                        = optional(string, "sites")
    private_dns_zone_group_name             = optional(string, "default")
    private_dns_zone_resource_ids           = optional(set(string), [])
    application_security_group_associations = optional(map(string), {})
    private_service_connection_name         = optional(string, null)
    network_interface_name                  = optional(string, null)
    location                                = optional(string, null)
    resource_group_name                     = optional(string, null)
    inherit_lock                            = optional(bool, true)
    lock = optional(object({
      kind = string
      name = optional(string, null)
    }), null)
    tags = optional(map(string), null)
    ip_configurations = optional(map(object({
      name               = string
      private_ip_address = string
      member_name        = optional(string, null)
    })), {})
    role_assignments = optional(map(object({
      role_definition_id_or_name             = string
      principal_id                           = string
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false)
      condition                              = optional(string, null)
      condition_version                      = optional(string, null)
      delegated_managed_identity_resource_id = optional(string, null)
      principal_type                         = optional(string, null)
    })), {})
  }))
```

Default: `{}`

### <a name="input_private_endpoints_manage_dns_zone_group"></a> [private\_endpoints\_manage\_dns\_zone\_group](#input\_private\_endpoints\_manage\_dns\_zone\_group)

Description: Whether to manage private DNS zone groups for private endpoints with this module. If false, private DNS records must be managed externally.

Type: `bool`

Default: `true`

### <a name="input_public_network_access_enabled"></a> [public\_network\_access\_enabled](#input\_public\_network\_access\_enabled)

Description: Whether public network access is enabled for the Function App.

Type: `bool`

Default: `null`

### <a name="input_role_assignments"></a> [role\_assignments](#input\_role\_assignments)

Description: A map of role assignments to create on the Function App. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time.

- `role_definition_id_or_name` - (Required) The role definition ID or role definition name to assign.
- `principal_id` - (Required) The principal ID to assign the role to.
- `description` - (Optional) The role assignment description.
- `skip_service_principal_aad_check` - (Optional) Whether to skip the Microsoft Entra service principal check. Defaults to `false`.
- `condition` - (Optional) The role assignment condition.
- `condition_version` - (Optional) The role assignment condition version. Possible value is `2.0`.
- `delegated_managed_identity_resource_id` - (Optional) The delegated managed identity resource ID for cross-tenant scenarios.
- `principal_type` - (Optional) The principal type. Possible values are `User`, `Group`, and `ServicePrincipal`.

Type:

```hcl
map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
```

Default: `{}`

### <a name="input_service_plan"></a> [service\_plan](#input\_service\_plan)

Description: Controls the App Service Plan used by the Function App.

- `name` - (Optional) The name of the App Service Plan. When unset, the module generates a CAF-aligned name using the `asp` prefix.
- `tags` - (Optional) Tags to apply to the App Service Plan. When unset, `var.tags` is inherited.

Type:

```hcl
object({
    name = optional(string, null)
    tags = optional(map(string), null)
  })
```

Default: `{}`

### <a name="input_site_config"></a> [site\_config](#input\_site\_config)

Description: App Service site configuration values exposed by this module. The networking and IP restriction fields follow the AVM App Service interface shape.

- `ip_restriction_default_action` - (Optional) The default action for main site IP restrictions. Possible values are `Allow` and `Deny`. Defaults to `Allow`.
- `ip_restriction` - (Optional) A list of main site IP restriction rules.
- `scm_ip_restriction_default_action` - (Optional) The default action for SCM site IP restrictions. Possible values are `Allow` and `Deny`. Defaults to `Allow`.
- `scm_ip_restriction` - (Optional) A list of SCM site IP restriction rules.
- `scm_use_main_ip_restriction` - (Optional) Whether SCM uses the main site IP restrictions. Defaults to `false`.
- `vnet_route_all_enabled` - (Optional) Whether all outbound traffic is routed through the integrated virtual network. Defaults to `false`.

Type:

```hcl
object({
    ip_restriction_default_action = optional(string, "Allow")
    ip_restriction = optional(list(object({
      action                    = optional(string, "Allow")
      ip_address                = optional(string, null)
      name                      = optional(string, null)
      priority                  = optional(number, 65000)
      service_tag               = optional(string, null)
      virtual_network_subnet_id = optional(string, null)
      headers = optional(object({
        x_azure_fdid      = optional(list(string), null)
        x_fd_health_probe = optional(list(string), null)
        x_forwarded_for   = optional(list(string), null)
        x_forwarded_host  = optional(list(string), null)
      }), null)
    })), [])
    scm_ip_restriction_default_action = optional(string, "Allow")
    scm_ip_restriction = optional(list(object({
      action                    = optional(string, "Allow")
      ip_address                = optional(string, null)
      name                      = optional(string, null)
      priority                  = optional(number, 65000)
      service_tag               = optional(string, null)
      virtual_network_subnet_id = optional(string, null)
      headers = optional(object({
        x_azure_fdid      = optional(list(string), null)
        x_fd_health_probe = optional(list(string), null)
        x_forwarded_for   = optional(list(string), null)
        x_forwarded_host  = optional(list(string), null)
      }), null)
    })), [])
    scm_use_main_ip_restriction = optional(bool, false)
    vnet_route_all_enabled      = optional(bool, false)
  })
```

Default: `{}`

### <a name="input_storage_account"></a> [storage\_account](#input\_storage\_account)

Description: Controls the Storage Account used by the Function App deployment package.

- `name` - (Optional) The name of the Storage Account. When unset, the module generates a deterministic globally unique name.
- `account_replication_type` - (Optional) The replication type for the Storage Account. Possible values are `LRS`, `GRS`, `RAGRS`, `ZRS`, `GZRS`, and `RAGZRS`. Defaults to `LRS`.
- `public_network_access_enabled` - (Optional) Whether public network access is enabled for the Storage Account. When unset, the provider default is used.
- `private_endpoints` - (Optional) A map of private endpoints to create for the Storage Account. When `virtual_network_subnet_id` is set, configure at least one endpoint so the Function App can access storage through Private Endpoint. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time.
- `private_endpoints.name` - (Optional) The name of the private endpoint. One will be generated if not set.
- `private_endpoints.subnet_resource_id` - (Required) The resource ID of the subnet where the private endpoint will be created. This must be different from the Flex Consumption VNET integration subnet.
- `private_endpoints.subresource_name` - (Required) The Storage Account subresource name. Possible values are `blob`, `queue`, `table`, `file`, `web`, and `dfs`.
- `private_endpoints.private_dns_zone_group_name` - (Optional) The private DNS zone group name. Defaults to `default`.
- `private_endpoints.private_dns_zone_resource_ids` - (Optional) A set of private DNS zone resource IDs to associate with the private endpoint.
- `private_endpoints.application_security_group_associations` - (Optional) A map of application security group resource IDs to associate with the private endpoint.
- `private_endpoints.private_service_connection_name` - (Optional) The private service connection name. One will be generated if not set.
- `private_endpoints.network_interface_name` - (Optional) The private endpoint network interface name.
- `private_endpoints.location` - (Optional) The private endpoint location. Defaults to `var.location`.
- `private_endpoints.resource_group_name` - (Optional) The private endpoint resource group name. Defaults to `var.resource_group_name`.
- `private_endpoints.inherit_lock` - (Optional) Whether this private endpoint inherits `var.lock` when no endpoint-specific lock is set. Defaults to `true`.
- `private_endpoints.lock` - (Optional) The lock to apply to this private endpoint.
- `private_endpoints.tags` - (Optional) Tags to apply to the private endpoint. When unset, `var.tags` is inherited.
- `private_endpoints.ip_configurations` - (Optional) A map of static IP configurations for the private endpoint.
- `private_endpoints.role_assignments` - (Optional) A map of role assignments to create on this private endpoint.
- `tags` - (Optional) Tags to apply to the Storage Account. When unset, `var.tags` is inherited.

Type:

```hcl
object({
    name                          = optional(string, null)
    account_replication_type      = optional(string, "LRS")
    public_network_access_enabled = optional(bool, null)
    private_endpoints = optional(map(object({
      name                                    = optional(string, null)
      subnet_resource_id                      = string
      subresource_name                        = string
      private_dns_zone_group_name             = optional(string, "default")
      private_dns_zone_resource_ids           = optional(set(string), [])
      application_security_group_associations = optional(map(string), {})
      private_service_connection_name         = optional(string, null)
      network_interface_name                  = optional(string, null)
      location                                = optional(string, null)
      resource_group_name                     = optional(string, null)
      inherit_lock                            = optional(bool, true)
      lock = optional(object({
        kind = string
        name = optional(string, null)
      }), null)
      tags = optional(map(string), null)
      ip_configurations = optional(map(object({
        name               = string
        private_ip_address = string
        member_name        = optional(string, null)
      })), {})
      role_assignments = optional(map(object({
        role_definition_id_or_name             = string
        principal_id                           = string
        description                            = optional(string, null)
        skip_service_principal_aad_check       = optional(bool, false)
        condition                              = optional(string, null)
        condition_version                      = optional(string, null)
        delegated_managed_identity_resource_id = optional(string, null)
        principal_type                         = optional(string, null)
      })), {})
    })), {})
    tags = optional(map(string), null)
  })
```

Default: `{}`

### <a name="input_tags"></a> [tags](#input\_tags)

Description: (Optional) Tags of the resource.

Type: `map(string)`

Default: `null`

### <a name="input_virtual_network_subnet_id"></a> [virtual\_network\_subnet\_id](#input\_virtual\_network\_subnet\_id)

Description: Existing subnet resource ID to use for VNET integration.

Type: `string`

Default: `null`
## Outputs

The following outputs are exported:

### <a name="output_api_key"></a> [api\_key](#output\_api\_key)

Description: Created Default Functions API Key. Null unless export\_api\_key is enabled.

### <a name="output_name"></a> [name](#output\_name)

Description: The name of the Function App.

### <a name="output_private_endpoint_names"></a> [private\_endpoint\_names](#output\_private\_endpoint\_names)

Description: The names of the private endpoints.

### <a name="output_private_endpoint_resource_ids"></a> [private\_endpoint\_resource\_ids](#output\_private\_endpoint\_resource\_ids)

Description: The resource IDs of the private endpoints.

### <a name="output_private_endpoints"></a> [private\_endpoints](#output\_private\_endpoints)

Description: A map of the private endpoints created.

### <a name="output_resource_id"></a> [resource\_id](#output\_resource\_id)

Description: The resource ID of the Function App.

### <a name="output_storage_account_private_endpoint_names"></a> [storage\_account\_private\_endpoint\_names](#output\_storage\_account\_private\_endpoint\_names)

Description: The names of the Storage Account private endpoints.

### <a name="output_storage_account_private_endpoint_resource_ids"></a> [storage\_account\_private\_endpoint\_resource\_ids](#output\_storage\_account\_private\_endpoint\_resource\_ids)

Description: The resource IDs of the Storage Account private endpoints.

### <a name="output_storage_account_private_endpoints"></a> [storage\_account\_private\_endpoints](#output\_storage\_account\_private\_endpoints)

Description: A map of the Storage Account private endpoints created.

### <a name="output_system_assigned_mi_principal_id"></a> [system\_assigned\_mi\_principal\_id](#output\_system\_assigned\_mi\_principal\_id)

Description: The principal ID of the system-assigned managed identity.

### <a name="output_system_assigned_mi_tenant_id"></a> [system\_assigned\_mi\_tenant\_id](#output\_system\_assigned\_mi\_tenant\_id)

Description: The tenant ID of the system-assigned managed identity.

## Modules

No modules.

## License

This project is licensed under the [MIT License](https://github.com/polymind-inc/terraform-azurerm-acmebot/blob/master/LICENSE)
<!-- END_TF_DOCS -->