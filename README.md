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
  mail_address        = "YOUR-EMAIL-ADDRESS"
  vault_uri           = azurerm_key_vault.default.vault_uri
  acmebot_version     = "5.0.1"
  tags = {
    workload = "acmebot"
  }

  azure_dns = {
    subscription_id = data.azurerm_client_config.current.subscription_id
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
  # acmebot_managed_identity_client_id = azurerm_user_assigned_identity.acmebot.client_id

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
- `acmebot_version` must be a Semantic Versioning 2.0.0 version, such as `5.0.1`, `5.0.1-beta.1`, or `5.0.1+build.5`.
- Secret inputs are marked as sensitive, but they are still stored in Terraform state when used to configure the Function App.
- This module adopts AVM-inspired interface patterns, but it is not an official Azure Verified Module.
- AVM-style `diagnostic_settings`, `lock`, `managed_identities`, `role_assignments`, and `private_endpoints` inputs can apply diagnostic settings, resource locks, managed identities, RBAC assignments, and Private Endpoints to the Function App.
- Acmebot requires either `managed_identities.system_assigned = true` or a user-assigned managed identity. To use a user-assigned managed identity, attach it through `managed_identities.user_assigned_resource_ids` and set `acmebot_managed_identity_client_id`; the module maps it to `Acmebot__ManagedIdentityClientId`.
- Child resources use CAF-aligned default name prefixes where applicable and can be overridden with `service_plan_name`, `log_analytics_workspace_name`, `application_insights_name`, and `storage_account_name`.
- VNET integration uses the AVM App Service naming pattern `virtual_network_subnet_id`, and outbound route-all is configured with `site_config.vnet_route_all_enabled`.
- IP restrictions use AVM App Service-style `site_config.ip_restriction`, `site_config.scm_ip_restriction`, `site_config.ip_restriction_default_action`, `site_config.scm_ip_restriction_default_action`, and `site_config.scm_use_main_ip_restriction`.
- Private Endpoints default to the Function App `sites` subresource and manage a private DNS zone group when `private_dns_zone_resource_ids` is set.
- Acmebot deployment uses Azure Functions zip deploy. The package URI is built from `acmebot_version` as `https://stacmebotprod.blob.core.windows.net/acmebot/v<major>/<version>.zip`.

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
- [azurerm_monitor_diagnostic_setting.function_app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) (resource)
- [azurerm_private_endpoint.function_app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) (resource)
- [azurerm_private_endpoint.function_app_unmanaged_dns_zone_groups](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint) (resource)
- [azurerm_private_endpoint_application_security_group_association.function_app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/private_endpoint_application_security_group_association) (resource)
- [azurerm_role_assignment.function_app](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) (resource)
- [azurerm_role_assignment.private_endpoint](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) (resource)
- [azurerm_service_plan.serverfarm](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/service_plan) (resource)
- [azurerm_storage_account.storage](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) (resource)
- [azurerm_storage_container.deployment](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) (resource)
- [random_string.deployment_container_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) (resource)
- [azurerm_client_config.current](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) (data source)
- [azurerm_function_app_host_keys.function](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/function_app_host_keys) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_acmebot_version"></a> [acmebot\_version](#input\_acmebot\_version)

Description: Acmebot package version to deploy. Must be a Semantic Versioning 2.0.0 version, such as 5.0.1, 5.0.1-beta.1, or 5.0.1+build.5.

Type: `string`

### <a name="input_location"></a> [location](#input\_location)

Description: Azure region to create resources.

Type: `string`

### <a name="input_mail_address"></a> [mail\_address](#input\_mail\_address)

Description: Email address for ACME account.

Type: `string`

### <a name="input_name"></a> [name](#input\_name)

Description: The name of the Function App.

Type: `string`

### <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name)

Description: Resource group name to be added.

Type: `string`

### <a name="input_vault_uri"></a> [vault\_uri](#input\_vault\_uri)

Description: URL of the Key Vault to store the issued certificate.

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_acme_endpoint"></a> [acme\_endpoint](#input\_acme\_endpoint)

Description: Certification authority ACME Endpoint.

Type: `string`

Default: `"https://acme-v02.api.letsencrypt.org/directory"`

### <a name="input_acmebot_managed_identity_client_id"></a> [acmebot\_managed\_identity\_client\_id](#input\_acmebot\_managed\_identity\_client\_id)

Description: The client ID of the user-assigned managed identity that Acmebot should use. Set this when Acmebot must authenticate with a user-assigned managed identity attached through managed\_identities.user\_assigned\_resource\_ids.

Type: `string`

Default: `null`

### <a name="input_additional_app_settings"></a> [additional\_app\_settings](#input\_additional\_app\_settings)

Description: Additional settings to set for the function app

Type: `map(string)`

Default: `{}`

### <a name="input_app_role_required"></a> [app\_role\_required](#input\_app\_role\_required)

Description: Specify whether additional App Role assignment is required during Azure AD authentication.

Type: `bool`

Default: `false`

### <a name="input_application_insights_name"></a> [application\_insights\_name](#input\_application\_insights\_name)

Description: Optional explicit name for the Application Insights component. When unset, the module generates a CAF-aligned name using the appi prefix.

Type: `string`

Default: `null`

### <a name="input_auth_settings"></a> [auth\_settings](#input\_auth\_settings)

Description: Authentication settings for the function app

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

### <a name="input_azure_dns"></a> [azure\_dns](#input\_azure\_dns)

Description: DNS Provider Configuration

Type:

```hcl
object({
    subscription_id = string
  })
```

Default: `null`

### <a name="input_azure_private_dns"></a> [azure\_private\_dns](#input\_azure\_private\_dns)

Description: n/a

Type:

```hcl
object({
    subscription_id = string
  })
```

Default: `null`

### <a name="input_cloudflare"></a> [cloudflare](#input\_cloudflare)

Description: n/a

Type:

```hcl
object({
    api_token = string
  })
```

Default: `null`

### <a name="input_custom_dns"></a> [custom\_dns](#input\_custom\_dns)

Description: n/a

Type:

```hcl
object({
    endpoint            = string
    api_key             = string
    api_key_header_name = string
    propagation_seconds = number
  })
```

Default: `null`

### <a name="input_diagnostic_settings"></a> [diagnostic\_settings](#input\_diagnostic\_settings)

Description: A map of diagnostic settings to create on the Function App. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time.

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

### <a name="input_dns_made_easy"></a> [dns\_made\_easy](#input\_dns\_made\_easy)

Description: n/a

Type:

```hcl
object({
    api_key    = string
    secret_key = string
  })
```

Default: `null`

### <a name="input_environment"></a> [environment](#input\_environment)

Description: The name of the Azure environment.

Type: `string`

Default: `"AzureCloud"`

### <a name="input_export_api_key"></a> [export\_api\_key](#input\_export\_api\_key)

Description: Whether to read and export the default function host key as output.

Type: `bool`

Default: `false`

### <a name="input_external_account_binding"></a> [external\_account\_binding](#input\_external\_account\_binding)

Description: n/a

Type:

```hcl
object({
    key_id    = string
    hmac_key  = string
    algorithm = string
  })
```

Default: `null`

### <a name="input_gandi"></a> [gandi](#input\_gandi)

Description: n/a

Type:

```hcl
object({
    api_key = string
  })
```

Default: `null`

### <a name="input_go_daddy"></a> [go\_daddy](#input\_go\_daddy)

Description: n/a

Type:

```hcl
object({
    api_key    = string
    api_secret = string
  })
```

Default: `null`

### <a name="input_google_dns"></a> [google\_dns](#input\_google\_dns)

Description: n/a

Type:

```hcl
object({
    key_file64 = string
  })
```

Default: `null`

### <a name="input_instance_memory_in_mb"></a> [instance\_memory\_in\_mb](#input\_instance\_memory\_in\_mb)

Description: Optional memory size in MB for Flex Consumption instances. Supported values are 512, 2048, and 4096.

Type: `number`

Default: `null`

### <a name="input_lock"></a> [lock](#input\_lock)

Description: Controls the Resource Lock configuration for the Function App. `kind` must be either `CanNotDelete` or `ReadOnly`; `name` is optional.

Type:

```hcl
object({
    kind = string
    name = optional(string, null)
  })
```

Default: `null`

### <a name="input_log_analytics_workspace_name"></a> [log\_analytics\_workspace\_name](#input\_log\_analytics\_workspace\_name)

Description: Optional explicit name for the Log Analytics workspace. When unset, the module generates a CAF-aligned name using the log prefix.

Type: `string`

Default: `null`

### <a name="input_managed_identities"></a> [managed\_identities](#input\_managed\_identities)

Description: Controls the Managed Identity configuration on the Function App. Acmebot requires either a system-assigned managed identity or a user-assigned managed identity with acmebot\_managed\_identity\_client\_id.

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

### <a name="input_mitigate_chain_order"></a> [mitigate\_chain\_order](#input\_mitigate\_chain\_order)

Description: Mitigate certificate ordering issues that occur with some services.

Type: `bool`

Default: `false`

### <a name="input_private_endpoints"></a> [private\_endpoints](#input\_private\_endpoints)

Description: A map of private endpoints to create for the Function App. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time.

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

### <a name="input_route_53"></a> [route\_53](#input\_route\_53)

Description: n/a

Type:

```hcl
object({
    access_key = string
    secret_key = string
    region     = string
  })
```

Default: `null`

### <a name="input_service_plan_name"></a> [service\_plan\_name](#input\_service\_plan\_name)

Description: Optional explicit name for the App Service Plan. When unset, the module generates a CAF-aligned name using the asp prefix.

Type: `string`

Default: `null`

### <a name="input_site_config"></a> [site\_config](#input\_site\_config)

Description: App Service site configuration values exposed by this module. The networking and IP restriction fields follow the AVM App Service interface shape.

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

### <a name="input_storage_account_name"></a> [storage\_account\_name](#input\_storage\_account\_name)

Description: Optional explicit storage account name. When unset, the module generates a deterministic globally-unique name.

Type: `string`

Default: `null`

### <a name="input_tags"></a> [tags](#input\_tags)

Description: (Optional) Tags of the resource.

Type: `map(string)`

Default: `null`

### <a name="input_trans_ip"></a> [trans\_ip](#input\_trans\_ip)

Description: n/a

Type:

```hcl
object({
    customer_name    = string
    private_key_name = string
  })
```

Default: `null`

### <a name="input_virtual_network_subnet_id"></a> [virtual\_network\_subnet\_id](#input\_virtual\_network\_subnet\_id)

Description: Existing subnet resource ID to use for VNET integration.

Type: `string`

Default: `null`

### <a name="input_webhook_url"></a> [webhook\_url](#input\_webhook\_url)

Description: The webhook where notifications will be sent.

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

### <a name="output_system_assigned_mi_principal_id"></a> [system\_assigned\_mi\_principal\_id](#output\_system\_assigned\_mi\_principal\_id)

Description: The principal ID of the system-assigned managed identity.

### <a name="output_system_assigned_mi_tenant_id"></a> [system\_assigned\_mi\_tenant\_id](#output\_system\_assigned\_mi\_tenant\_id)

Description: The tenant ID of the system-assigned managed identity.

## Modules

No modules.

## License

This project is licensed under the [MIT License](https://github.com/polymind-inc/terraform-azurerm-acmebot/blob/master/LICENSE)
<!-- END_TF_DOCS -->