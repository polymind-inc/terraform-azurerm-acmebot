variable "name" {
  type        = string
  description = "The name of the Function App."
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-]*[A-Za-z0-9]$", var.name)) && length(var.name) >= 2 && length(var.name) <= 32
    error_message = "name must be 2-32 characters; contain only letters, numbers, and hyphens; and start and end with a letter or number."
  }
}

variable "parent_id" {
  type        = string
  description = "The fully-qualified resource group resource ID where resources will be deployed."
  nullable    = false

  validation {
    condition     = can(provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id))
    error_message = "parent_id must be a valid Azure resource group resource ID."
  }
}

variable "location" {
  type        = string
  description = "Azure region to create resources."
  nullable    = false

  validation {
    condition     = length(var.location) > 0
    error_message = "location must not be empty."
  }
}

variable "enable_telemetry" {
  type        = bool
  description = <<DESCRIPTION
Whether to enable AVM telemetry on the underlying Azure Verified Modules consumed by this module. When `true`, the value is forwarded to every AVM child module's `enable_telemetry` input. Defaults to `false` because this module is a community pattern and is not an official Azure Verified Module; consumers must opt in explicitly to send telemetry through the AVM `modtm` provider.
DESCRIPTION
  default     = false
  nullable    = false
}

variable "auth_settings" {
  type = object({
    enabled = bool
    active_directory = object({
      client_id            = string
      tenant_auth_endpoint = string
    })
  })
  description = <<DESCRIPTION
Controls App Service Authentication for the Function App. The client secret is supplied separately via `var.auth_settings_client_secret`.

- `enabled` - (Required) Whether App Service Authentication is enabled.
- `active_directory.client_id` - (Required) The Microsoft Entra application client ID.
- `active_directory.tenant_auth_endpoint` - (Required) The tenant-specific Microsoft Entra authorization endpoint.
DESCRIPTION
  default     = null
}

variable "auth_settings_client_secret" {
  type        = string
  default     = null
  sensitive   = true
  description = "The Microsoft Entra application client secret used by App Service Authentication. Required when `var.auth_settings` is set. The value is wired to the Function App as the `MICROSOFT_PROVIDER_AUTHENTICATION_SECRET` app setting and stored in Terraform state."

  validation {
    condition     = var.auth_settings == null || var.auth_settings_client_secret != null
    error_message = "auth_settings_client_secret must be set when auth_settings is configured."
  }
}

variable "private_endpoints_manage_dns_zone_group" {
  type        = bool
  description = "Whether to manage private DNS zone groups for private endpoints with this module. If false, private DNS records must be managed externally."
  default     = true
  nullable    = false
}

variable "private_endpoints" {
  type = map(object({
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
  description = <<DESCRIPTION
A map of private endpoints to create for the Function App. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time.

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
DESCRIPTION
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for private_endpoint in values(var.private_endpoints) : can(provider::azapi::parse_resource_id(
        "Microsoft.Network/virtualNetworks/subnets",
        private_endpoint.subnet_resource_id
      ))
    ])
    error_message = "private_endpoints[*].subnet_resource_id must be a valid subnet resource ID."
  }

  validation {
    condition = alltrue(flatten([
      for private_endpoint in values(var.private_endpoints) : [
        for private_dns_zone_resource_id in private_endpoint.private_dns_zone_resource_ids : can(provider::azapi::parse_resource_id(
          "Microsoft.Network/privateDnsZones",
          private_dns_zone_resource_id
        ))
      ]
    ]))
    error_message = "private_endpoints[*].private_dns_zone_resource_ids must contain valid private DNS zone resource IDs."
  }

  validation {
    condition = alltrue(flatten([
      for private_endpoint in values(var.private_endpoints) : [
        for application_security_group_resource_id in values(private_endpoint.application_security_group_associations) : can(provider::azapi::parse_resource_id(
          "Microsoft.Network/applicationSecurityGroups",
          application_security_group_resource_id
        ))
      ]
    ]))
    error_message = "private_endpoints[*].application_security_group_associations values must be valid application security group resource IDs."
  }

  validation {
    condition = alltrue([
      for private_endpoint in values(var.private_endpoints) : private_endpoint.lock == null ? true : contains(["CanNotDelete", "ReadOnly"], private_endpoint.lock.kind)
    ])
    error_message = "private_endpoints[*].lock.kind must be either \"CanNotDelete\" or \"ReadOnly\"."
  }

  validation {
    condition = alltrue(flatten([
      for private_endpoint in values(var.private_endpoints) : [
        for assignment in values(private_endpoint.role_assignments) : assignment.condition_version == null || assignment.condition_version == "2.0"
      ]
    ]))
    error_message = "private_endpoints[*].role_assignments[*].condition_version must be null or \"2.0\"."
  }

  validation {
    condition = alltrue(flatten([
      for private_endpoint in values(var.private_endpoints) : [
        for assignment in values(private_endpoint.role_assignments) : assignment.principal_type == null || contains(["User", "Group", "ServicePrincipal"], assignment.principal_type)
      ]
    ]))
    error_message = "private_endpoints[*].role_assignments[*].principal_type must be null, \"User\", \"Group\", or \"ServicePrincipal\"."
  }
}

variable "additional_app_settings" {
  type        = map(string)
  description = "Additional application settings to set on the Function App. Keys prefixed with `Acmebot__`, keys prefixed with `Acmebot:`, keys prefixed with `AzureWebJobsStorage`, and `MICROSOFT_PROVIDER_AUTHENTICATION_SECRET` are reserved by this module."
  default     = {}
  sensitive   = true

  validation {
    condition = alltrue([
      for key in keys(var.additional_app_settings) : !startswith(key, "Acmebot__") && !startswith(key, "Acmebot:") && !startswith(key, "AzureWebJobsStorage") && key != "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"
    ])
    error_message = "additional_app_settings cannot override reserved Acmebot, AzureWebJobsStorage, or authentication secret settings."
  }
}

variable "tags" {
  type        = map(string)
  description = "(Optional) Tags of the resource."
  default     = null
  nullable    = true
}

variable "site_config" {
  type = object({
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
  description = <<DESCRIPTION
App Service site configuration values exposed by this module. The networking and IP restriction fields follow the AVM App Service interface shape.

- `ip_restriction_default_action` - (Optional) The default action for main site IP restrictions. Possible values are `Allow` and `Deny`. Defaults to `Deny`.
- `ip_restriction` - (Optional) A list of main site IP restriction rules.
- `scm_ip_restriction_default_action` - (Optional) The default action for SCM site IP restrictions. Possible values are `Allow` and `Deny`. Defaults to `Deny`.
- `scm_ip_restriction` - (Optional) A list of SCM site IP restriction rules.
- `scm_use_main_ip_restriction` - (Optional) Whether SCM uses the main site IP restrictions. Defaults to `true`.
- `vnet_route_all_enabled` - (Optional) Whether all outbound traffic is routed through the integrated virtual network. Defaults to `true` when `virtual_network_subnet_id` is set, otherwise `false`.
DESCRIPTION
  default     = {}
  nullable    = false

  validation {
    condition     = var.site_config.ip_restriction_default_action == null || contains(["Allow", "Deny"], var.site_config.ip_restriction_default_action)
    error_message = "site_config.ip_restriction_default_action must be either \"Allow\" or \"Deny\"."
  }

  validation {
    condition = alltrue([
      for rule in var.site_config.ip_restriction : contains(["Allow", "Deny"], rule.action)
    ])
    error_message = "site_config.ip_restriction[*].action must be either \"Allow\" or \"Deny\"."
  }

  validation {
    condition = alltrue([
      for rule in var.site_config.ip_restriction : length([for value in [rule.ip_address, rule.service_tag, rule.virtual_network_subnet_id] : value if value != null]) == 1
    ])
    error_message = "Each site_config.ip_restriction rule must set exactly one of ip_address, service_tag, or virtual_network_subnet_id."
  }

  validation {
    condition = alltrue([
      for rule in var.site_config.ip_restriction : rule.virtual_network_subnet_id == null || can(provider::azapi::parse_resource_id(
        "Microsoft.Network/virtualNetworks/subnets",
        rule.virtual_network_subnet_id
      ))
    ])
    error_message = "site_config.ip_restriction[*].virtual_network_subnet_id must be a valid subnet resource ID."
  }

  validation {
    condition     = var.site_config.scm_ip_restriction_default_action == null || contains(["Allow", "Deny"], var.site_config.scm_ip_restriction_default_action)
    error_message = "site_config.scm_ip_restriction_default_action must be either \"Allow\" or \"Deny\"."
  }

  validation {
    condition = alltrue([
      for rule in var.site_config.scm_ip_restriction : contains(["Allow", "Deny"], rule.action)
    ])
    error_message = "site_config.scm_ip_restriction[*].action must be either \"Allow\" or \"Deny\"."
  }

  validation {
    condition = alltrue([
      for rule in var.site_config.scm_ip_restriction : length([for value in [rule.ip_address, rule.service_tag, rule.virtual_network_subnet_id] : value if value != null]) == 1
    ])
    error_message = "Each site_config.scm_ip_restriction rule must set exactly one of ip_address, service_tag, or virtual_network_subnet_id."
  }

  validation {
    condition = alltrue([
      for rule in var.site_config.scm_ip_restriction : rule.virtual_network_subnet_id == null || can(provider::azapi::parse_resource_id(
        "Microsoft.Network/virtualNetworks/subnets",
        rule.virtual_network_subnet_id
      ))
    ])
    error_message = "site_config.scm_ip_restriction[*].virtual_network_subnet_id must be a valid subnet resource ID."
  }
}

variable "managed_identities" {
  type = object({
    system_assigned            = optional(bool, true)
    user_assigned_resource_ids = optional(set(string), [])
  })
  description = <<DESCRIPTION
Controls the Managed Identity configuration on the Function App. A system-assigned managed identity is enabled by default and is used for Storage when `storage_managed_identity.user_assigned_resource_id` is unset. A user-assigned managed identity can also be attached and selected by Acmebot with `acmebot.managed_identity_client_id`, and selected for Storage with `storage_managed_identity.user_assigned_resource_id`.

- `system_assigned` - (Optional) Whether to enable a system-assigned managed identity. Defaults to `true`. Can be `false` only when Storage and Acmebot are both configured to use an attached user-assigned managed identity.
- `user_assigned_resource_ids` - (Optional) A set of user-assigned managed identity resource IDs to attach to the Function App.
DESCRIPTION
  default = {
    system_assigned = true
  }
  nullable = false

  validation {
    condition = alltrue([
      for resource_id in var.managed_identities.user_assigned_resource_ids : can(provider::azapi::parse_resource_id(
        "Microsoft.ManagedIdentity/userAssignedIdentities",
        resource_id
      ))
    ])
    error_message = "managed_identities.user_assigned_resource_ids must contain valid user-assigned managed identity resource IDs."
  }
}

variable "lock" {
  type = object({
    kind = string
    name = optional(string, null)
  })
  description = <<DESCRIPTION
Controls the Resource Lock configuration for the Function App.

- `kind` - (Required) The lock kind. Possible values are `CanNotDelete` and `ReadOnly`.
- `name` - (Optional) The lock name. If not specified, a name will be generated based on the `kind` value.
DESCRIPTION
  default     = null

  validation {
    condition     = var.lock == null ? true : contains(["CanNotDelete", "ReadOnly"], var.lock.kind)
    error_message = "lock.kind must be either \"CanNotDelete\" or \"ReadOnly\"."
  }
}

variable "role_assignments" {
  type = map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
  description = <<DESCRIPTION
A map of role assignments to create on the Function App. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time.

- `role_definition_id_or_name` - (Required) The role definition ID or role definition name to assign.
- `principal_id` - (Required) The principal ID to assign the role to.
- `description` - (Optional) The role assignment description.
- `skip_service_principal_aad_check` - (Optional) Whether to skip the Microsoft Entra service principal check. Defaults to `false`.
- `condition` - (Optional) The role assignment condition.
- `condition_version` - (Optional) The role assignment condition version. Possible value is `2.0`.
- `delegated_managed_identity_resource_id` - (Optional) The delegated managed identity resource ID for cross-tenant scenarios.
- `principal_type` - (Optional) The principal type. Possible values are `User`, `Group`, and `ServicePrincipal`.
DESCRIPTION
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for assignment in values(var.role_assignments) : assignment.condition_version == null || assignment.condition_version == "2.0"
    ])
    error_message = "role_assignments[*].condition_version must be null or \"2.0\"."
  }

  validation {
    condition = alltrue([
      for assignment in values(var.role_assignments) : assignment.principal_type == null || contains(["User", "Group", "ServicePrincipal"], assignment.principal_type)
    ])
    error_message = "role_assignments[*].principal_type must be null, \"User\", \"Group\", or \"ServicePrincipal\"."
  }
}

variable "storage_account" {
  type = object({
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
  description = <<DESCRIPTION
Controls the Storage Account used by the Function App deployment package.

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
- `private_endpoints.lock` - (Optional) The lock to apply to this private endpoint. When unset, `var.lock` is inherited.
- `private_endpoints.tags` - (Optional) Tags to apply to the private endpoint. When unset, `var.tags` is inherited.
- `private_endpoints.ip_configurations` - (Optional) A map of static IP configurations for the private endpoint.
- `private_endpoints.role_assignments` - (Optional) A map of role assignments to create on this private endpoint.
- `tags` - (Optional) Tags to apply to the Storage Account. When unset, `var.tags` is inherited.
DESCRIPTION
  default     = {}
  nullable    = false

  validation {
    condition     = var.storage_account.name == null || can(regex("^[a-z0-9]{3,24}$", var.storage_account.name))
    error_message = "storage_account.name must be 3-24 characters of lowercase letters and numbers."
  }

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.storage_account.account_replication_type)
    error_message = "storage_account.account_replication_type must be one of: \"LRS\", \"GRS\", \"RAGRS\", \"ZRS\", \"GZRS\", or \"RAGZRS\"."
  }

  validation {
    condition     = var.storage_account.network_rules == null || contains(["Allow", "Deny"], var.storage_account.network_rules.default_action)
    error_message = "storage_account.network_rules.default_action must be either \"Allow\" or \"Deny\"."
  }

  validation {
    condition = var.storage_account.network_rules == null ? true : alltrue([
      for bypass in var.storage_account.network_rules.bypass : contains(["AzureServices", "Logging", "Metrics", "None"], bypass)
    ])
    error_message = "storage_account.network_rules.bypass entries must be one of: \"AzureServices\", \"Logging\", \"Metrics\", or \"None\"."
  }

  validation {
    condition = var.storage_account.blob_properties == null || var.storage_account.blob_properties.change_feed == null || var.storage_account.blob_properties.change_feed.retention_in_days == null || (
      var.storage_account.blob_properties.change_feed.retention_in_days >= 1 && var.storage_account.blob_properties.change_feed.retention_in_days <= 146000
    )
    error_message = "storage_account.blob_properties.change_feed.retention_in_days must be between 1 and 146000."
  }

  validation {
    condition = var.storage_account.blob_properties == null || var.storage_account.blob_properties.delete_retention_policy == null || var.storage_account.blob_properties.delete_retention_policy.days == null || (
      var.storage_account.blob_properties.delete_retention_policy.days >= 1 && var.storage_account.blob_properties.delete_retention_policy.days <= 365
    )
    error_message = "storage_account.blob_properties.delete_retention_policy.days must be between 1 and 365."
  }

  validation {
    condition = var.storage_account.blob_properties == null || var.storage_account.blob_properties.container_delete_retention_policy == null || var.storage_account.blob_properties.container_delete_retention_policy.days == null || (
      var.storage_account.blob_properties.container_delete_retention_policy.days >= 1 && var.storage_account.blob_properties.container_delete_retention_policy.days <= 365
    )
    error_message = "storage_account.blob_properties.container_delete_retention_policy.days must be between 1 and 365."
  }

  validation {
    condition = var.storage_account.blob_properties == null || var.storage_account.blob_properties.restore_policy == null || var.storage_account.blob_properties.restore_policy.days == null || (
      var.storage_account.blob_properties.restore_policy.days >= 1 && var.storage_account.blob_properties.restore_policy.days <= 365
    )
    error_message = "storage_account.blob_properties.restore_policy.days must be between 1 and 365."
  }

  validation {
    condition = (
      var.storage_account.blob_properties == null ||
      var.storage_account.blob_properties.restore_policy == null ||
      var.storage_account.blob_properties.restore_policy.days == null ||
      var.storage_account.blob_properties.delete_retention_policy == null ||
      var.storage_account.blob_properties.delete_retention_policy.days == null ||
      var.storage_account.blob_properties.restore_policy.days < var.storage_account.blob_properties.delete_retention_policy.days
    )
    error_message = "storage_account.blob_properties.restore_policy.days must be less than storage_account.blob_properties.delete_retention_policy.days."
  }

  validation {
    condition = var.storage_account.public_network_access_enabled != true ? alltrue([
      for subresource_name in ["blob", "queue", "table"] : contains([for private_endpoint in values(var.storage_account.private_endpoints) : private_endpoint.subresource_name], subresource_name)
    ]) : true
    error_message = "storage_account.private_endpoints must include blob, queue, and table endpoints when storage_account.public_network_access_enabled is false or unset."
  }

  validation {
    condition = alltrue([
      for private_endpoint in values(var.storage_account.private_endpoints) : can(provider::azapi::parse_resource_id(
        "Microsoft.Network/virtualNetworks/subnets",
        private_endpoint.subnet_resource_id
      ))
    ])
    error_message = "storage_account.private_endpoints[*].subnet_resource_id must be a valid subnet resource ID."
  }

  validation {
    condition = alltrue([
      for private_endpoint in values(var.storage_account.private_endpoints) : contains(["blob", "queue", "table", "file", "web", "dfs"], private_endpoint.subresource_name)
    ])
    error_message = "storage_account.private_endpoints[*].subresource_name must be one of: \"blob\", \"queue\", \"table\", \"file\", \"web\", or \"dfs\"."
  }

  validation {
    condition = alltrue(flatten([
      for private_endpoint in values(var.storage_account.private_endpoints) : [
        for private_dns_zone_resource_id in private_endpoint.private_dns_zone_resource_ids : can(provider::azapi::parse_resource_id(
          "Microsoft.Network/privateDnsZones",
          private_dns_zone_resource_id
        ))
      ]
    ]))
    error_message = "storage_account.private_endpoints[*].private_dns_zone_resource_ids must contain valid private DNS zone resource IDs."
  }

  validation {
    condition = alltrue(flatten([
      for private_endpoint in values(var.storage_account.private_endpoints) : [
        for application_security_group_resource_id in values(private_endpoint.application_security_group_associations) : can(provider::azapi::parse_resource_id(
          "Microsoft.Network/applicationSecurityGroups",
          application_security_group_resource_id
        ))
      ]
    ]))
    error_message = "storage_account.private_endpoints[*].application_security_group_associations values must be valid application security group resource IDs."
  }

  validation {
    condition = alltrue([
      for private_endpoint in values(var.storage_account.private_endpoints) : private_endpoint.lock == null ? true : contains(["CanNotDelete", "ReadOnly"], private_endpoint.lock.kind)
    ])
    error_message = "storage_account.private_endpoints[*].lock.kind must be either \"CanNotDelete\" or \"ReadOnly\"."
  }

  validation {
    condition = alltrue(flatten([
      for private_endpoint in values(var.storage_account.private_endpoints) : [
        for assignment in values(private_endpoint.role_assignments) : assignment.condition_version == null || assignment.condition_version == "2.0"
      ]
    ]))
    error_message = "storage_account.private_endpoints[*].role_assignments[*].condition_version must be null or \"2.0\"."
  }

  validation {
    condition = alltrue(flatten([
      for private_endpoint in values(var.storage_account.private_endpoints) : [
        for assignment in values(private_endpoint.role_assignments) : assignment.principal_type == null || contains(["User", "Group", "ServicePrincipal"], assignment.principal_type)
      ]
    ]))
    error_message = "storage_account.private_endpoints[*].role_assignments[*].principal_type must be null, \"User\", \"Group\", or \"ServicePrincipal\"."
  }
}

variable "deployment_container" {
  type = object({
    name = optional(string, null)
  })
  description = <<DESCRIPTION
Controls the Storage Container used by the Function App deployment package.

- `name` - (Optional) The name of the Storage Container. When unset, the module generates a CAF-aligned name with a random suffix to avoid collisions.
DESCRIPTION
  default     = {}
  nullable    = false

  validation {
    condition     = var.deployment_container.name == null || (can(regex("^[a-z0-9]+(-[a-z0-9]+)*$", var.deployment_container.name)) && length(var.deployment_container.name) >= 3 && length(var.deployment_container.name) <= 63)
    error_message = "deployment_container.name must be 3-63 characters of lowercase letters, numbers, and hyphens; start and end with a letter or number; and not contain consecutive hyphens."
  }
}

variable "service_plan" {
  type = object({
    name           = optional(string, null)
    zone_redundant = optional(bool, false)
    tags           = optional(map(string), null)
  })
  description = <<DESCRIPTION
Controls the App Service Plan used by the Function App.

- `name` - (Optional) The name of the App Service Plan. When unset, the module generates a CAF-aligned name using the `asp` prefix.
- `zone_redundant` - (Optional) Whether the App Service Plan is zone redundant. Defaults to `false`. For Flex Consumption (`FC1`), zone redundancy is only available in Azure regions that advertise the `FCZONEREDUNDANCY` capability; leave this `false` in unsupported regions.
- `tags` - (Optional) Tags to apply to the App Service Plan. When unset, `var.tags` is inherited.
DESCRIPTION
  default     = {}
  nullable    = false

  validation {
    condition     = var.service_plan.name == null || can(regex("^[A-Za-z0-9][A-Za-z0-9-]*[A-Za-z0-9]$", var.service_plan.name))
    error_message = "service_plan.name must contain only letters, numbers, and hyphens, and start and end with a letter or number."
  }
}

variable "log_analytics_workspace" {
  type = object({
    resource_id       = optional(string, null)
    name              = optional(string, null)
    retention_in_days = optional(number, 30)
    tags              = optional(map(string), null)
  })
  description = <<DESCRIPTION
Controls the Log Analytics workspace used by Application Insights.

- `resource_id` - (Optional) The resource ID of an existing Log Analytics workspace to use for Application Insights. When set, this module does not create a workspace.
- `name` - (Optional) The name of the Log Analytics workspace. When unset, the module generates a CAF-aligned name using the `log` prefix.
- `retention_in_days` - (Optional) The workspace retention period in days when the module creates the workspace. Defaults to `30`.
- `tags` - (Optional) Tags to apply to the module-created Log Analytics workspace. When unset, `var.tags` is inherited.
DESCRIPTION
  default     = {}
  nullable    = false

  validation {
    condition = var.log_analytics_workspace.resource_id == null || can(provider::azapi::parse_resource_id(
      "Microsoft.OperationalInsights/workspaces",
      var.log_analytics_workspace.resource_id
    ))
    error_message = "log_analytics_workspace.resource_id must be a valid Log Analytics workspace resource ID."
  }

  validation {
    condition     = var.log_analytics_workspace.name == null || can(regex("^[A-Za-z0-9][A-Za-z0-9-]*[A-Za-z0-9]$", var.log_analytics_workspace.name))
    error_message = "log_analytics_workspace.name must contain only letters, numbers, and hyphens, and start and end with a letter or number."
  }

  validation {
    condition     = var.log_analytics_workspace.retention_in_days >= 30 && var.log_analytics_workspace.retention_in_days <= 730
    error_message = "log_analytics_workspace.retention_in_days must be between 30 and 730."
  }
}

variable "application_insights" {
  type = object({
    resource_id = optional(string, null)
    name        = optional(string, null)
    tags        = optional(map(string), null)
  })
  description = <<DESCRIPTION
Controls the Application Insights component connected to the Function App.

- `resource_id` - (Optional) The resource ID of an existing Application Insights component. When set, this module does not create an Application Insights component.
- `name` - (Optional) The name of the Application Insights component. When unset, the module generates a CAF-aligned name using the `appi` prefix.
- `tags` - (Optional) Tags to apply to the module-created Application Insights component. When unset, `var.tags` is inherited.
DESCRIPTION
  default     = {}
  nullable    = false

  validation {
    condition = var.application_insights.resource_id == null || can(provider::azapi::parse_resource_id(
      "Microsoft.Insights/components",
      var.application_insights.resource_id
    ))
    error_message = "application_insights.resource_id must be a valid Application Insights component resource ID."
  }

  validation {
    condition     = var.application_insights.name == null || can(regex("^[A-Za-z0-9][A-Za-z0-9-]*[A-Za-z0-9]$", var.application_insights.name))
    error_message = "application_insights.name must contain only letters, numbers, and hyphens, and start and end with a letter or number."
  }
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Whether public network access is enabled for the Function App. Defaults to `false`."
  default     = null

  validation {
    condition     = var.public_network_access_enabled != true ? length(var.private_endpoints) > 0 : true
    error_message = "private_endpoints must be set when public_network_access_enabled is false or unset so the Function App has a private ingress path."
  }
}

variable "virtual_network_subnet_id" {
  type        = string
  description = "Existing subnet resource ID to use for VNET integration."
  default     = null

  validation {
    condition = var.virtual_network_subnet_id == null || can(provider::azapi::parse_resource_id(
      "Microsoft.Network/virtualNetworks/subnets",
      var.virtual_network_subnet_id
    ))
    error_message = "virtual_network_subnet_id must be a valid subnet resource ID."
  }

  validation {
    condition     = length(var.storage_account.private_endpoints) == 0 || var.virtual_network_subnet_id != null
    error_message = "virtual_network_subnet_id must be set when storage_account.private_endpoints is set so the Function App can route Storage Account traffic through the virtual network."
  }

  validation {
    condition     = var.storage_account.public_network_access_enabled != true ? var.virtual_network_subnet_id != null : true
    error_message = "virtual_network_subnet_id must be set when storage_account.public_network_access_enabled is false or unset so the Function App can reach Storage through Private Endpoint."
  }

  validation {
    condition     = var.virtual_network_subnet_id == null || length(var.storage_account.private_endpoints) > 0
    error_message = "storage_account.private_endpoints must be set when virtual_network_subnet_id is set so the Function App can access its Storage Account through Private Endpoint."
  }

  validation {
    condition = var.virtual_network_subnet_id == null ? true : alltrue([
      for private_endpoint in values(var.storage_account.private_endpoints) : lower(private_endpoint.subnet_resource_id) != lower(var.virtual_network_subnet_id)
    ])
    error_message = "storage_account.private_endpoints[*].subnet_resource_id must be different from virtual_network_subnet_id because the Flex Consumption VNET integration subnet cannot be used for private endpoints."
  }
}

variable "storage_managed_identity" {
  type = object({
    user_assigned_resource_id = optional(string, null)
  })
  description = <<DESCRIPTION
Controls the managed identity used by `AzureWebJobsStorage` and Flex Consumption deployment storage.

- `user_assigned_resource_id` - (Optional) The resource ID of an attached user-assigned managed identity. When unset, the Function App uses its system-assigned managed identity for Storage. The module always configures `AzureWebJobsStorage__credential = managedidentity`; when this value is set, it also sets `AzureWebJobsStorage__clientId` from this identity and configures Flex deployment storage with `UserAssignedIdentity`.
DESCRIPTION
  default     = {}
  nullable    = false

  validation {
    condition = var.storage_managed_identity.user_assigned_resource_id == null || can(provider::azapi::parse_resource_id(
      "Microsoft.ManagedIdentity/userAssignedIdentities",
      var.storage_managed_identity.user_assigned_resource_id
    ))
    error_message = "storage_managed_identity.user_assigned_resource_id must be a valid user-assigned managed identity resource ID."
  }

  validation {
    condition     = var.managed_identities.system_assigned == true || var.storage_managed_identity.user_assigned_resource_id != null
    error_message = "storage_managed_identity.user_assigned_resource_id must be set when managed_identities.system_assigned is false."
  }

  validation {
    condition     = var.storage_managed_identity.user_assigned_resource_id == null || contains([for resource_id in var.managed_identities.user_assigned_resource_ids : lower(resource_id)], lower(var.storage_managed_identity.user_assigned_resource_id))
    error_message = "storage_managed_identity.user_assigned_resource_id must also be attached through managed_identities.user_assigned_resource_ids."
  }
}

variable "maximum_instance_count" {
  type        = number
  description = "Maximum scale-out instance count for the Function App. Defaults to 10."
  default     = 10
  nullable    = false

  validation {
    condition     = var.maximum_instance_count >= 1 && var.maximum_instance_count <= 1000
    error_message = "maximum_instance_count must be between 1 and 1000."
  }
}

variable "instance_memory_in_mb" {
  type        = number
  description = "Memory size in MB for Flex Consumption instances. Supported values are 512, 2048, and 4096. Defaults to 2048."
  default     = 2048
  nullable    = false

  validation {
    condition     = contains([512, 2048, 4096], var.instance_memory_in_mb)
    error_message = "instance_memory_in_mb must be one of 512, 2048, or 4096."
  }
}

variable "export_api_key" {
  type        = bool
  description = "Whether to read and export the default function host key as output."
  default     = false
}

# Acmebot Configuration
variable "acmebot" {
  type = object({
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
  description = <<DESCRIPTION
Controls Acmebot workload configuration. This object is sensitive because DNS provider credentials, webhook URLs, and external account binding secrets are passed to the Function App as application settings and stored in Terraform state.

- `version` - (Required) The Acmebot package version to deploy. Must be a Semantic Versioning 2.0.0 version, such as `5.0.1`, `5.0.1-beta.1`, or `5.0.1+build.5`, and must match a published release. Pick an existing version from the [Acmebot releases](https://github.com/shibayan/keyvault-acmebot/releases) (use the release tag without the leading `v`); validation only checks the format, so an unpublished version fails at deploy time. This module requires the Flex Consumption package layout published under `v5` and later.
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
DESCRIPTION
  nullable    = false
  sensitive   = true

  validation {
    condition     = can(regex("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(\\.(0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?(\\+([0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*))?$", var.acmebot.version))
    error_message = "acmebot.version must be a Semantic Versioning 2.0.0 version, such as 5.0.1, 5.0.1-beta.1, or 5.0.1+build.5."
  }

  validation {
    # Defer to the SemVer validation above for malformed input; only enforce the
    # major when the version starts with a numeric segment.
    condition     = can(regex("^(0|[1-9][0-9]*)\\.", var.acmebot.version)) ? tonumber(split(".", var.acmebot.version)[0]) >= 5 : true
    error_message = "acmebot.version major version must be 5 or greater; this module requires the Flex Consumption package layout published under v5 and later."
  }

  validation {
    condition     = can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", var.acmebot.mail_address)) && !startswith(lower(var.acmebot.mail_address), "mailto:")
    error_message = "acmebot.mail_address must be an email address without the mailto: prefix."
  }

  validation {
    condition     = contains(["AzureCloud", "AzureChinaCloud", "AzureUSGovernment"], var.acmebot.environment)
    error_message = "acmebot.environment must be one of: \"AzureCloud\", \"AzureChinaCloud\", or \"AzureUSGovernment\"."
  }

  validation {
    condition     = var.acmebot.renew_before_expiry >= 0 && var.acmebot.renew_before_expiry <= 365
    error_message = "acmebot.renew_before_expiry must be between 0 and 365."
  }

  validation {
    condition     = var.acmebot.managed_identity_client_id == null || can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.acmebot.managed_identity_client_id))
    error_message = "acmebot.managed_identity_client_id must be a valid GUID."
  }

  validation {
    condition     = var.acmebot.managed_identity_client_id == null || length(var.managed_identities.user_assigned_resource_ids) > 0
    error_message = "acmebot.managed_identity_client_id can only be set when at least one user-assigned managed identity is attached through managed_identities.user_assigned_resource_ids."
  }

  validation {
    condition     = var.managed_identities.system_assigned == true || var.acmebot.managed_identity_client_id != null
    error_message = "acmebot.managed_identity_client_id must be set when managed_identities.system_assigned is false so Acmebot can use an attached user-assigned managed identity."
  }

  validation {
    condition     = var.acmebot.external_account_binding == null || contains(["HS256", "HS384", "HS512"], var.acmebot.external_account_binding.algorithm)
    error_message = "acmebot.external_account_binding.algorithm must be one of: \"HS256\", \"HS384\", or \"HS512\"."
  }

  validation {
    condition = length(compact([
      var.acmebot.dns_providers.akamai != null ? "akamai" : "",
      var.acmebot.dns_providers.azure_dns != null ? "azure_dns" : "",
      var.acmebot.dns_providers.azure_private_dns != null ? "azure_private_dns" : "",
      var.acmebot.dns_providers.cloudflare != null ? "cloudflare" : "",
      var.acmebot.dns_providers.custom_dns != null ? "custom_dns" : "",
      var.acmebot.dns_providers.dns_made_easy != null ? "dns_made_easy" : "",
      var.acmebot.dns_providers.gandi_live_dns != null ? "gandi_live_dns" : "",
      var.acmebot.dns_providers.go_daddy != null ? "go_daddy" : "",
      var.acmebot.dns_providers.google_dns != null ? "google_dns" : "",
      var.acmebot.dns_providers.ionos_dns != null ? "ionos_dns" : "",
      var.acmebot.dns_providers.ovh != null ? "ovh" : "",
      var.acmebot.dns_providers.power_dns != null ? "power_dns" : "",
      var.acmebot.dns_providers.regfish != null ? "regfish" : "",
      var.acmebot.dns_providers.route_53 != null ? "route_53" : "",
      var.acmebot.dns_providers.trans_ip != null ? "trans_ip" : "",
      var.acmebot.dns_providers.united_domains != null ? "united_domains" : "",
    ])) > 0
    error_message = "At least one acmebot.dns_providers entry must be configured."
  }
}
