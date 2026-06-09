<!-- BEGIN_TF_DOCS -->
# Azure Acmebot Terraform Module

Deploy Azure Acmebot on Azure Functions Flex Consumption with managed identity
storage access, optional private networking, optional App Service Authentication,
and managed observability resources.

This module uses an AzAPI-first implementation with Azure Verified Module
(AVM)-aligned interface patterns. It is published in the Terraform Registry under
the `azurerm` namespace, but it is not an official Azure Verified Module.

## Usage

Use the module from the Terraform Registry. The following example shows the main
inputs for a private deployment; see the runnable examples for complete
configurations.

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

  acmebot = {
    version      = "5.0.1"
    mail_address = "admin@example.com"
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
        subnet_resource_id = azurerm_subnet.private_endpoints.id
        subresource_name   = "blob"
        private_dns_zone_resource_ids = [
          azurerm_private_dns_zone.storage["blob"].id
        ]
      }
      queue = {
        subnet_resource_id = azurerm_subnet.private_endpoints.id
        subresource_name   = "queue"
        private_dns_zone_resource_ids = [
          azurerm_private_dns_zone.storage["queue"].id
        ]
      }
      table = {
        subnet_resource_id = azurerm_subnet.private_endpoints.id
        subresource_name   = "table"
        private_dns_zone_resource_ids = [
          azurerm_private_dns_zone.storage["table"].id
        ]
      }
    }
  }

  private_endpoints = {
    sites = {
      subnet_resource_id = azurerm_subnet.private_endpoints.id
      private_dns_zone_resource_ids = [
        azurerm_private_dns_zone.sites.id
      ]
    }
  }

  virtual_network_subnet_id = azurerm_subnet.functions.id

  managed_identities = {
    system_assigned = true
  }

  site_config = {
    vnet_route_all_enabled             = true
    ip_restriction_default_action      = "Deny"
    scm_ip_restriction_default_action  = "Deny"
    scm_use_main_ip_restriction        = true
  }

  log_analytics_workspace = {
    retention_in_days = 90
  }

  lock = {
    kind = "CanNotDelete"
  }
}
```

## Examples

Runnable examples are available under [`examples`](examples):

- [`default`](examples/default) - A public quickstart with minimal networking, a system-assigned managed identity, a Key Vault target, and Azure DNS.
- [`complete`](examples/complete) - A fully private deployment with VNET integration, Function App and Storage Account Private Endpoints, private DNS, a user-assigned managed identity, and a resource lock.

## Design Notes

### Core Inputs

- `name` is the Function App name. It must be 2-32 characters, contain only
  letters, numbers, and hyphens, and start and end with a letter or number.
- `parent_id` is the AVM-aligned deployment scope input and must be the resource
  ID of an existing resource group.
- `acmebot.version` must target a published Acmebot v5 or later package. The
  validation checks the version format, but an unpublished package version fails
  during deployment.
- Acmebot workload settings are grouped under `acmebot`, including ACME account
  settings, Key Vault target, DNS provider configuration, webhook configuration,
  and External Account Binding.

### Security and Identity

- Secret inputs are marked as sensitive, but they are still stored in Terraform
  state when used to configure the Function App.
- `AzureWebJobsStorage` and Flex Consumption deployment storage use managed
  identity. By default, the module uses the Function App system-assigned identity.
- The selected Storage identity receives Storage Blob Data Owner, Storage Queue
  Data Contributor, and Storage Table Data Contributor on the module-created
  Storage Account.
- To make Acmebot use a user-assigned identity, attach it through
  `managed_identities.user_assigned_resource_ids` and set
  `acmebot.managed_identity_client_id`.
- Storage Account shared key authorization is disabled by default. Blob versioning,
  change feed, soft delete, Entra-first portal auth, and infrastructure encryption
  are enabled by default.

### Networking

- The module is private by default: Function App and Storage Account public
  network access default to disabled.
- Quickstart examples explicitly enable public access and do not configure App
  Service Authentication. Use them for evaluation, not as a locked-down
  production baseline.
- When `virtual_network_subnet_id` is set, configure Storage private endpoints so
  the Function App can reach its Storage Account through Private Endpoint.
- When Storage public access is disabled, configure `blob`, `queue`, and `table`
  private endpoints.
- The Flex Consumption VNET integration subnet cannot host private endpoints, so
  use a separate subnet for private endpoints.
- `acmebot.use_system_name_server` controls whether Acmebot uses the platform DNS
  resolver instead of Google Public DNS for ACME challenge verification.

### Operations

- Set `log_analytics_workspace.resource_id` and/or
  `application_insights.resource_id` to reuse existing monitoring resources.
- Child resources inherit `var.tags` by default and support child-specific tag
  overrides where Azure supports tags.
- Child resource settings can be overridden with `storage_account`,
  `deployment_container`, `service_plan`, `log_analytics_workspace`, and
  `application_insights`.
- AVM-style `lock`, `managed_identities`, `role_assignments`, and
  `private_endpoints` inputs can apply resource locks, managed identities, RBAC
  assignments, and Private Endpoints to the Function App.

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.10.0, < 2.0.0)

- <a name="requirement_azapi"></a> [azapi](#requirement\_azapi) (>= 2.9.0, < 3.0.0)

- <a name="requirement_modtm"></a> [modtm](#requirement\_modtm) (~> 0.3)

- <a name="requirement_random"></a> [random](#requirement\_random) (>= 3.5.0, < 4.0.0)

## Providers

The following providers are used by this module:

- <a name="provider_azapi"></a> [azapi](#provider\_azapi) (>= 2.9.0, < 3.0.0)

- <a name="provider_random"></a> [random](#provider\_random) (>= 3.5.0, < 4.0.0)

## Resources

The following resources are used by this module:

- [azapi_resource.application_insights](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) (resource)
- [azapi_resource.deployment](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) (resource)
- [azapi_resource.log_analytics_workspace](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) (resource)
- [azapi_resource.storage_account_function_app_role_assignment](https://registry.terraform.io/providers/Azure/azapi/latest/docs/resources/resource) (resource)
- [random_string.deployment_container_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/string) (resource)
- [azapi_resource.application_insights](https://registry.terraform.io/providers/Azure/azapi/latest/docs/data-sources/resource) (data source)
- [azapi_resource.storage_user_assigned_identity](https://registry.terraform.io/providers/Azure/azapi/latest/docs/data-sources/resource) (data source)
- [azapi_resource_action.function_host_keys](https://registry.terraform.io/providers/Azure/azapi/latest/docs/data-sources/resource_action) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_acmebot"></a> [acmebot](#input\_acmebot)

Description: Controls Acmebot workload configuration. This object is sensitive because DNS provider credentials, webhook URLs, and external account binding secrets are passed to the Function App as application settings and stored in Terraform state.

- `version` - (Required) The Acmebot package version to deploy. Must be a Semantic Versioning 2.0.0 version, such as `5.0.1`, `5.0.1-beta.1`, or `5.0.1+build.5`, and must match a published release. Pick an existing version from the [Acmebot releases](https://github.com/polymind-inc/acmebot/releases) (use the release tag without the leading `v`, which maps to the `acmebot.zip` asset under `v<version>`); validation only checks the format, so an unpublished version fails at deploy time. This module requires the Flex Consumption package layout published under `v5` and later.
- `mail_address` - (Required) The email address for the ACME account, without the `mailto:` prefix.
- `vault_uri` - (Required) The Key Vault URI where issued certificates are stored.
- `acme_endpoint` - (Optional) The certification authority ACME endpoint. Defaults to Let's Encrypt production.
- `environment` - (Optional) The Azure environment name. Defaults to `AzureCloud`. Set `AzureChinaCloud` or `AzureUSGovernment` explicitly for sovereign cloud deployments.
- `webhook_url` - (Optional) The webhook URL where Acmebot sends notifications.
- `preferred_chain` - (Optional) Preferred issuer chain name when the ACME CA offers alternate chains.
- `preferred_profile` - (Optional) Preferred ACME profile when the CA advertises profiles.
- `renew_before_expiry` - (Optional) Number of days before certificate expiry when scheduled renewal should run. Defaults to `30`.
- `use_system_name_server` - (Optional) Whether Acmebot uses the system DNS resolver instead of Google Public DNS for challenge verification. Defaults to `true` when `virtual_network_subnet_id` is set or `environment` is a sovereign cloud, and `false` otherwise. Set explicitly to override.
- `app_role_required` - (Optional) Whether additional app role assignment is required during Microsoft Entra authentication. Defaults to `false`.
- `managed_identity_client_id` - (Optional) The client ID of the user-assigned managed identity Acmebot should use. When set, the identity must also be attached through `managed_identities.user_assigned_resource_ids`.
- `external_account_binding` - (Optional) External Account Binding settings for ACME providers that require account binding.
- `dns_providers` - (Optional) DNS provider settings for Acmebot. Supported providers are `akamai`, `azure_dns`, `azure_private_dns`, `cloudflare`, `custom_dns`, `dns_made_easy`, `gandi_live_dns`, `go_daddy`, `google_dns`, `ionos_dns`, `ovh`, `power_dns`, `regfish`, `route_53`, `trans_ip`, and `united_domains`.

Type:

```hcl
object({
    version                    = string
    mail_address               = string
    vault_uri                  = string
    acme_endpoint              = optional(string, "https://acme-v02.api.letsencrypt.org/directory")
    environment                = optional(string, "AzureCloud")
    webhook_url                = optional(string, null)
    preferred_chain            = optional(string, null)
    preferred_profile          = optional(string, null)
    renew_before_expiry        = optional(number, 30)
    use_system_name_server     = optional(bool, null)
    app_role_required          = optional(bool, false)
    managed_identity_client_id = optional(string, null)
    external_account_binding = optional(object({
      key_id    = string
      hmac_key  = string
      algorithm = optional(string, "HS256")
    }), null)
    dns_providers = optional(object({
      akamai = optional(object({
        host          = string
        client_token  = string
        client_secret = string
        access_token  = string
      }), null)
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
        api_key_header_name = optional(string, "X-Api-Key")
        propagation_seconds = optional(number, 180)
      }), null)
      dns_made_easy = optional(object({
        api_key    = string
        secret_key = string
      }), null)
      gandi_live_dns = optional(object({
        api_key = string
      }), null)
      go_daddy = optional(object({
        api_key    = string
        api_secret = string
      }), null)
      google_dns = optional(object({
        key_file64 = string
      }), null)
      ionos_dns = optional(object({
        api_key = string
      }), null)
      ovh = optional(object({
        endpoint           = optional(string, "https://eu.api.ovh.com/1.0/")
        application_key    = string
        application_secret = string
        consumer_key       = string
      }), null)
      power_dns = optional(object({
        endpoint  = string
        api_key   = string
        server_id = optional(string, "localhost")
      }), null)
      regfish = optional(object({
        api_key = string
      }), null)
      route_53 = optional(object({
        access_key = string
        secret_key = string
        region     = optional(string, "us-east-1")
      }), null)
      trans_ip = optional(object({
        customer_name    = string
        private_key_name = string
      }), null)
      united_domains = optional(object({
        api_key = string
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

### <a name="input_parent_id"></a> [parent\_id](#input\_parent\_id)

Description: The fully-qualified resource group resource ID where resources will be deployed.

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_additional_app_settings"></a> [additional\_app\_settings](#input\_additional\_app\_settings)

Description: Additional application settings to set on the Function App. Keys prefixed with `Acmebot__`, keys prefixed with `Acmebot:`, keys prefixed with `AzureWebJobsStorage`, and `MICROSOFT_PROVIDER_AUTHENTICATION_SECRET` are reserved by this module.

Type: `map(string)`

Default: `{}`

### <a name="input_application_insights"></a> [application\_insights](#input\_application\_insights)

Description: Controls the Application Insights component connected to the Function App.

- `resource_id` - (Optional) The resource ID of an existing Application Insights component. When set, this module does not create an Application Insights component.
- `name` - (Optional) The name of the Application Insights component. When unset, the module generates a CAF-aligned name using the `appi` prefix.
- `tags` - (Optional) Tags to apply to the module-created Application Insights component. When unset, `var.tags` is inherited.

Type:

```hcl
object({
    resource_id = optional(string, null)
    name        = optional(string, null)
    tags        = optional(map(string), null)
  })
```

Default: `{}`

### <a name="input_auth_settings"></a> [auth\_settings](#input\_auth\_settings)

Description: Controls App Service Authentication for the Function App. The client secret is supplied separately via `var.auth_settings_client_secret`.

- `enabled` - (Required) Whether App Service Authentication is enabled.
- `active_directory.client_id` - (Required) The Microsoft Entra application client ID.
- `active_directory.tenant_auth_endpoint` - (Required) The tenant-specific Microsoft Entra authorization endpoint.

Type:

```hcl
object({
    enabled = bool
    active_directory = object({
      client_id            = string
      tenant_auth_endpoint = string
    })
  })
```

Default: `null`

### <a name="input_auth_settings_client_secret"></a> [auth\_settings\_client\_secret](#input\_auth\_settings\_client\_secret)

Description: The Microsoft Entra application client secret used by App Service Authentication. Required when `var.auth_settings` is set. The value is wired to the Function App as the `MICROSOFT_PROVIDER_AUTHENTICATION_SECRET` app setting and stored in Terraform state.

Type: `string`

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

### <a name="input_enable_telemetry"></a> [enable\_telemetry](#input\_enable\_telemetry)

Description: Whether to enable AVM telemetry on the underlying Azure Verified Modules consumed by this module. When `true`, the value is forwarded to every AVM child module's `enable_telemetry` input. Defaults to `false` because this module is a community pattern and is not an official Azure Verified Module; consumers must opt in explicitly to send telemetry through the AVM `modtm` provider.

Type: `bool`

Default: `false`

### <a name="input_export_api_key"></a> [export\_api\_key](#input\_export\_api\_key)

Description: Whether to read and export the default function host key as output.

Type: `bool`

Default: `false`

### <a name="input_instance_memory_in_mb"></a> [instance\_memory\_in\_mb](#input\_instance\_memory\_in\_mb)

Description: Memory size in MB for Flex Consumption instances. Supported values are 512, 2048, and 4096. Defaults to 2048.

Type: `number`

Default: `2048`

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

- `resource_id` - (Optional) The resource ID of an existing Log Analytics workspace to use for Application Insights. When set, this module does not create a workspace.
- `name` - (Optional) The name of the Log Analytics workspace. When unset, the module generates a CAF-aligned name using the `log` prefix.
- `retention_in_days` - (Optional) The workspace retention period in days when the module creates the workspace. Defaults to `30`.
- `tags` - (Optional) Tags to apply to the module-created Log Analytics workspace. When unset, `var.tags` is inherited.

Type:

```hcl
object({
    resource_id       = optional(string, null)
    name              = optional(string, null)
    retention_in_days = optional(number, 30)
    tags              = optional(map(string), null)
  })
```

Default: `{}`

### <a name="input_managed_identities"></a> [managed\_identities](#input\_managed\_identities)

Description: Controls the Managed Identity configuration on the Function App. A system-assigned managed identity is enabled by default and is used for Storage when `storage_managed_identity.user_assigned_resource_id` is unset. A user-assigned managed identity can also be attached and selected by Acmebot with `acmebot.managed_identity_client_id`, and selected for Storage with `storage_managed_identity.user_assigned_resource_id`.

- `system_assigned` - (Optional) Whether to enable a system-assigned managed identity. Defaults to `true`. Can be `false` only when Storage and Acmebot are both configured to use an attached user-assigned managed identity.
- `user_assigned_resource_ids` - (Optional) A set of user-assigned managed identity resource IDs to attach to the Function App.

Type:

```hcl
object({
    system_assigned            = optional(bool, true)
    user_assigned_resource_ids = optional(set(string), [])
  })
```

Default:

```json
{
  "system_assigned": true
}
```

### <a name="input_maximum_instance_count"></a> [maximum\_instance\_count](#input\_maximum\_instance\_count)

Description: Maximum scale-out instance count for the Function App. Defaults to 10.

Type: `number`

Default: `10`

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
- `resource_group_name` - (Optional) The private endpoint resource group name. Defaults to the parent resource group.
- `lock` - (Optional) The lock to apply to this private endpoint. When unset, `var.lock` is inherited.
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
    lock = optional(object({
      kind = string
      name = optional(string, null)
    }), null)
    tags = optional(map(string), null)
    ip_configurations = optional(map(object({
      name               = string
      private_ip_address = string
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

Description: Whether public network access is enabled for the Function App. Defaults to `false`.

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
- `zone_redundant` - (Optional) Whether the App Service Plan is zone redundant. Defaults to `false`. For Flex Consumption (`FC1`), zone redundancy is only available in Azure regions that advertise the `FCZONEREDUNDANCY` capability; leave this `false` in unsupported regions.
- `tags` - (Optional) Tags to apply to the App Service Plan. When unset, `var.tags` is inherited.

Type:

```hcl
object({
    name           = optional(string, null)
    zone_redundant = optional(bool, false)
    tags           = optional(map(string), null)
  })
```

Default: `{}`

### <a name="input_site_config"></a> [site\_config](#input\_site\_config)

Description: App Service site configuration values exposed by this module. The networking and IP restriction fields follow the AVM App Service interface shape.

- `ip_restriction_default_action` - (Optional) The default action for main site IP restrictions. Possible values are `Allow` and `Deny`. Defaults to `Deny`.
- `ip_restriction` - (Optional) A list of main site IP restriction rules.
- `scm_ip_restriction_default_action` - (Optional) The default action for SCM site IP restrictions. Possible values are `Allow` and `Deny`. Defaults to `Deny`.
- `scm_ip_restriction` - (Optional) A list of SCM site IP restriction rules.
- `scm_use_main_ip_restriction` - (Optional) Whether SCM uses the main site IP restrictions. Defaults to `true`.
- `vnet_route_all_enabled` - (Optional) Whether all outbound traffic is routed through the integrated virtual network. Defaults to `true` when `virtual_network_subnet_id` is set, otherwise `false`.

Type:

```hcl
object({
    ip_restriction_default_action = optional(string, null)
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
    scm_ip_restriction_default_action = optional(string, null)
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
    scm_use_main_ip_restriction = optional(bool, null)
    vnet_route_all_enabled      = optional(bool, null)
  })
```

Default: `{}`

### <a name="input_storage_account"></a> [storage\_account](#input\_storage\_account)

Description: Controls the Storage Account used by the Function App deployment package.

- `name` - (Optional) The name of the Storage Account. When unset, the module generates a deterministic globally unique name.
- `account_replication_type` - (Optional) The replication type for the Storage Account. Possible values are `LRS`, `GRS`, `RAGRS`, `ZRS`, `GZRS`, and `RAGZRS`. Defaults to `LRS`.
- `default_to_oauth_authentication` - (Optional) Whether Azure portal data-plane access defaults to Microsoft Entra authorization. Defaults to `true`.
- `infrastructure_encryption_enabled` - (Optional) Whether infrastructure encryption is enabled. Defaults to `true`.
- `public_network_access_enabled` - (Optional) Whether public network access is enabled for the Storage Account. Defaults to `false`. Set it to `true` for public deployments, or configure `virtual_network_subnet_id` with `blob`/`queue`/`table` private endpoints for private deployments.
- `shared_access_key_enabled` - (Optional) Whether Shared Key authorization is enabled. Defaults to `false`; `AzureWebJobsStorage` uses managed identity.
- `blob_properties` - (Optional) Blob service properties. Defaults enable blob versioning, change feed, blob soft delete, and container soft delete with 30-day retention.
- `network_rules` - (Optional) Storage firewall rules. Defaults to `null` to leave public-network reachability controlled by `public_network_access_enabled`; set an object to configure selected networks.
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
- `private_endpoints.resource_group_name` - (Optional) The private endpoint resource group name. Defaults to the parent resource group.
- `private_endpoints.lock` - (Optional) The lock to apply to this private endpoint. When unset, no lock is applied.
- `private_endpoints.tags` - (Optional) Tags to apply to the private endpoint. When unset, `var.tags` is inherited.
- `private_endpoints.ip_configurations` - (Optional) A map of static IP configurations for the private endpoint.
- `private_endpoints.role_assignments` - (Optional) A map of role assignments to create on this private endpoint.
- `tags` - (Optional) Tags to apply to the Storage Account. When unset, `var.tags` is inherited.

Type:

```hcl
object({
    name                              = optional(string, null)
    account_replication_type          = optional(string, "LRS")
    default_to_oauth_authentication   = optional(bool, true)
    infrastructure_encryption_enabled = optional(bool, true)
    public_network_access_enabled     = optional(bool, null)
    shared_access_key_enabled         = optional(bool, false)
    blob_properties = optional(object({
      change_feed = optional(object({
        enabled           = optional(bool)
        retention_in_days = optional(number)
      }))
      container_delete_retention_policy = optional(object({
        allow_permanent_delete = optional(bool)
        days                   = optional(number)
        enabled                = optional(bool)
      }))
      delete_retention_policy = optional(object({
        allow_permanent_delete = optional(bool)
        days                   = optional(number)
        enabled                = optional(bool)
      }))
      restore_policy = optional(object({
        days    = optional(number)
        enabled = bool
      }))
      versioning_enabled = optional(bool)
      }), {
      change_feed = {
        enabled           = true
        retention_in_days = 30
      }
      container_delete_retention_policy = {
        enabled = true
        days    = 30
      }
      delete_retention_policy = {
        enabled = true
        days    = 30
      }
      versioning_enabled = true
    })
    network_rules = optional(object({
      bypass                     = optional(set(string), ["AzureServices"])
      default_action             = optional(string, "Deny")
      ip_rules                   = optional(set(string), [])
      virtual_network_subnet_ids = optional(set(string), [])
      private_link_access = optional(list(object({
        endpoint_resource_id = string
        endpoint_tenant_id   = optional(string)
      })), null)
    }), null)
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
      lock = optional(object({
        kind = string
        name = optional(string, null)
      }), null)
      tags = optional(map(string), null)
      ip_configurations = optional(map(object({
        name               = string
        private_ip_address = string
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

### <a name="input_storage_managed_identity"></a> [storage\_managed\_identity](#input\_storage\_managed\_identity)

Description: Controls the managed identity used by `AzureWebJobsStorage` and Flex Consumption deployment storage.

- `user_assigned_resource_id` - (Optional) The resource ID of an attached user-assigned managed identity. When unset, the Function App uses its system-assigned managed identity for Storage. The module always configures `AzureWebJobsStorage__credential = managedidentity`; when this value is set, it also sets `AzureWebJobsStorage__clientId` from this identity and configures Flex deployment storage with `UserAssignedIdentity`.

Type:

```hcl
object({
    user_assigned_resource_id = optional(string, null)
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

### <a name="output_private_endpoints"></a> [private\_endpoints](#output\_private\_endpoints)

Description: A map of the Function App private endpoints created.

### <a name="output_resource"></a> [resource](#output\_resource)

Description: The Function App resource.

### <a name="output_resource_id"></a> [resource\_id](#output\_resource\_id)

Description: The resource ID of the Function App.

### <a name="output_storage_account_name"></a> [storage\_account\_name](#output\_storage\_account\_name)

Description: The name of the Storage Account.

### <a name="output_storage_account_private_endpoints"></a> [storage\_account\_private\_endpoints](#output\_storage\_account\_private\_endpoints)

Description: A map of the Storage Account private endpoints created.

### <a name="output_storage_account_resource_id"></a> [storage\_account\_resource\_id](#output\_storage\_account\_resource\_id)

Description: The resource ID of the Storage Account.

### <a name="output_system_assigned_mi_principal_id"></a> [system\_assigned\_mi\_principal\_id](#output\_system\_assigned\_mi\_principal\_id)

Description: The principal ID of the system-assigned managed identity. Null when the system-assigned identity is disabled.

## Modules

The following Modules are called:

### <a name="module_serverfarm"></a> [serverfarm](#module\_serverfarm)

Source: Azure/avm-res-web-serverfarm/azurerm

Version: ~> 2.0

### <a name="module_storage"></a> [storage](#module\_storage)

Source: Azure/avm-res-storage-storageaccount/azurerm

Version: ~> 0.7.0

### <a name="module_this"></a> [this](#module\_this)

Source: Azure/avm-res-web-site/azurerm

Version: ~> 0.22.0

## License

This project is licensed under the [MIT License](https://github.com/polymind-inc/terraform-azurerm-acmebot/blob/master/LICENSE)
<!-- END_TF_DOCS -->
