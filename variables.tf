variable "name" {
  type        = string
  description = "The name of the Function App."
  nullable    = false

  validation {
    condition     = can(regex("^[A-Za-z0-9][A-Za-z0-9-]*[A-Za-z0-9]$", var.name)) && length(var.name) >= 2 && length(var.name) <= 32
    error_message = "name must be 2-32 characters; contain only letters, numbers, and hyphens; and start and end with a letter or number."
  }
}

variable "resource_group_name" {
  type        = string
  description = "Resource group name to be added."
}

variable "location" {
  type        = string
  description = "Azure region to create resources."
}

variable "auth_settings" {
  type = object({
    enabled = bool
    active_directory = object({
      client_id            = string
      client_secret        = string
      tenant_auth_endpoint = string
    })
  })
  description = <<DESCRIPTION
Controls App Service Authentication for the Function App.

- `enabled` - (Required) Whether App Service Authentication is enabled.
- `active_directory.client_id` - (Required) The Microsoft Entra application client ID.
- `active_directory.client_secret` - (Required) The Microsoft Entra application client secret. This value is stored in Terraform state.
- `active_directory.tenant_auth_endpoint` - (Required) The tenant-specific Microsoft Entra authorization endpoint.
DESCRIPTION
  default     = null
  sensitive   = true
}

variable "diagnostic_settings" {
  type = map(object({
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
  description = <<DESCRIPTION
A map of diagnostic settings to create on the Function App. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time.

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
DESCRIPTION
  default     = {}
  nullable    = false

  validation {
    condition     = alltrue([for _, v in var.diagnostic_settings : contains(["Dedicated", "AzureDiagnostics"], v.log_analytics_destination_type)])
    error_message = "Log analytics destination type must be one of: \"Dedicated\", \"AzureDiagnostics\"."
  }

  validation {
    condition = alltrue([
      for _, v in var.diagnostic_settings : v.workspace_resource_id != null || v.storage_account_resource_id != null || v.event_hub_authorization_rule_resource_id != null || v.marketplace_partner_resource_id != null
    ])
    error_message = "At least one of workspace_resource_id, storage_account_resource_id, event_hub_authorization_rule_resource_id, or marketplace_partner_resource_id must be set."
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
- `resource_group_name` - (Optional) The private endpoint resource group name. Defaults to `var.resource_group_name`.
- `inherit_lock` - (Optional) Whether this private endpoint inherits `var.lock` when no endpoint-specific lock is set. Defaults to `true`.
- `lock` - (Optional) The lock to apply to this private endpoint.
- `tags` - (Optional) Tags to apply to this private endpoint. When unset, `var.tags` is inherited.
- `ip_configurations` - (Optional) A map of static IP configurations for the private endpoint.
- `role_assignments` - (Optional) A map of role assignments to create on this private endpoint.
DESCRIPTION
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for private_endpoint in values(var.private_endpoints) : can(regex("^/subscriptions/[^/]+/resourcegroups/[^/]+/providers/microsoft\\.network/virtualnetworks/[^/]+/subnets/[^/]+$", lower(private_endpoint.subnet_resource_id)))
    ])
    error_message = "private_endpoints[*].subnet_resource_id must be a valid subnet resource ID."
  }

  validation {
    condition = alltrue(flatten([
      for private_endpoint in values(var.private_endpoints) : [
        for private_dns_zone_resource_id in private_endpoint.private_dns_zone_resource_ids : can(regex("^/subscriptions/[^/]+/resourcegroups/[^/]+/providers/microsoft\\.network/privatednszones/[^/]+$", lower(private_dns_zone_resource_id)))
      ]
    ]))
    error_message = "private_endpoints[*].private_dns_zone_resource_ids must contain valid private DNS zone resource IDs."
  }

  validation {
    condition = alltrue(flatten([
      for private_endpoint in values(var.private_endpoints) : [
        for application_security_group_resource_id in values(private_endpoint.application_security_group_associations) : can(regex("^/subscriptions/[^/]+/resourcegroups/[^/]+/providers/microsoft\\.network/applicationsecuritygroups/[^/]+$", lower(application_security_group_resource_id)))
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
  description = "Additional application settings to set on the Function App. Keys prefixed with `Acmebot__`, keys prefixed with `Acmebot:`, and `MICROSOFT_PROVIDER_AUTHENTICATION_SECRET` are reserved by this module."
  default     = {}
  sensitive   = true

  validation {
    condition = alltrue([
      for key in keys(var.additional_app_settings) : !startswith(key, "Acmebot__") && !startswith(key, "Acmebot:") && key != "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"
    ])
    error_message = "additional_app_settings cannot override reserved Acmebot or authentication secret settings."
  }
}

variable "tags" {
  type        = map(string)
  description = "(Optional) Tags of the resource."
  default     = null
}

variable "site_config" {
  type = object({
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
  description = <<DESCRIPTION
App Service site configuration values exposed by this module. The networking and IP restriction fields follow the AVM App Service interface shape.

- `ip_restriction_default_action` - (Optional) The default action for main site IP restrictions. Possible values are `Allow` and `Deny`. Defaults to `Allow`.
- `ip_restriction` - (Optional) A list of main site IP restriction rules.
- `scm_ip_restriction_default_action` - (Optional) The default action for SCM site IP restrictions. Possible values are `Allow` and `Deny`. Defaults to `Allow`.
- `scm_ip_restriction` - (Optional) A list of SCM site IP restriction rules.
- `scm_use_main_ip_restriction` - (Optional) Whether SCM uses the main site IP restrictions. Defaults to `false`.
- `vnet_route_all_enabled` - (Optional) Whether all outbound traffic is routed through the integrated virtual network. Defaults to `false`.
DESCRIPTION
  default     = {}
  nullable    = false

  validation {
    condition     = contains(["Allow", "Deny"], var.site_config.ip_restriction_default_action)
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
      for rule in var.site_config.ip_restriction : rule.virtual_network_subnet_id == null || can(regex("^/subscriptions/[^/]+/resourcegroups/[^/]+/providers/microsoft\\.network/virtualnetworks/[^/]+/subnets/[^/]+$", lower(rule.virtual_network_subnet_id)))
    ])
    error_message = "site_config.ip_restriction[*].virtual_network_subnet_id must be a valid subnet resource ID."
  }

  validation {
    condition     = contains(["Allow", "Deny"], var.site_config.scm_ip_restriction_default_action)
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
      for rule in var.site_config.scm_ip_restriction : rule.virtual_network_subnet_id == null || can(regex("^/subscriptions/[^/]+/resourcegroups/[^/]+/providers/microsoft\\.network/virtualnetworks/[^/]+/subnets/[^/]+$", lower(rule.virtual_network_subnet_id)))
    ])
    error_message = "site_config.scm_ip_restriction[*].virtual_network_subnet_id must be a valid subnet resource ID."
  }
}

variable "managed_identities" {
  type = object({
    system_assigned            = optional(bool, false)
    user_assigned_resource_ids = optional(set(string), [])
  })
  description = <<DESCRIPTION
Controls the Managed Identity configuration on the Function App. Acmebot requires either a system-assigned managed identity or a user-assigned managed identity with `acmebot.managed_identity_client_id`.

- `system_assigned` - (Optional) Whether to enable a system-assigned managed identity. Defaults to `false`.
- `user_assigned_resource_ids` - (Optional) A set of user-assigned managed identity resource IDs to attach to the Function App.
DESCRIPTION
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for resource_id in var.managed_identities.user_assigned_resource_ids : can(regex("^/subscriptions/[^/]+/resourcegroups/[^/]+/providers/microsoft\\.managedidentity/userassignedidentities/[^/]+$", lower(resource_id)))
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
    name                     = optional(string, null)
    account_replication_type = optional(string, "LRS")
    tags                     = optional(map(string), null)
  })
  description = <<DESCRIPTION
Controls the Storage Account used by the Function App deployment package.

- `name` - (Optional) The name of the Storage Account. When unset, the module generates a deterministic globally unique name.
- `account_replication_type` - (Optional) The replication type for the Storage Account. Possible values are `LRS`, `GRS`, `RAGRS`, `ZRS`, `GZRS`, and `RAGZRS`. Defaults to `LRS`.
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
    condition     = var.deployment_container.name == null || can(regex("^[a-z0-9](?:[a-z0-9-]{1,61}[a-z0-9])?$", var.deployment_container.name))
    error_message = "deployment_container.name must be 3-63 characters of lowercase letters, numbers, and hyphens, and start and end with a letter or number."
  }
}

variable "service_plan" {
  type = object({
    name = optional(string, null)
    tags = optional(map(string), null)
  })
  description = <<DESCRIPTION
Controls the App Service Plan used by the Function App.

- `name` - (Optional) The name of the App Service Plan. When unset, the module generates a CAF-aligned name using the `asp` prefix.
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
    name              = optional(string, null)
    retention_in_days = optional(number, 30)
    tags              = optional(map(string), null)
  })
  description = <<DESCRIPTION
Controls the Log Analytics workspace used by Application Insights.

- `name` - (Optional) The name of the Log Analytics workspace. When unset, the module generates a CAF-aligned name using the `log` prefix.
- `retention_in_days` - (Optional) The workspace retention period in days. Defaults to `30`.
- `tags` - (Optional) Tags to apply to the Log Analytics workspace. When unset, `var.tags` is inherited.
DESCRIPTION
  default     = {}
  nullable    = false

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
    name = optional(string, null)
    tags = optional(map(string), null)
  })
  description = <<DESCRIPTION
Controls the Application Insights component connected to the Function App.

- `name` - (Optional) The name of the Application Insights component. When unset, the module generates a CAF-aligned name using the `appi` prefix.
- `tags` - (Optional) Tags to apply to the Application Insights component. When unset, `var.tags` is inherited.
DESCRIPTION
  default     = {}
  nullable    = false

  validation {
    condition     = var.application_insights.name == null || can(regex("^[A-Za-z0-9][A-Za-z0-9-]*[A-Za-z0-9]$", var.application_insights.name))
    error_message = "application_insights.name must contain only letters, numbers, and hyphens, and start and end with a letter or number."
  }
}

variable "public_network_access_enabled" {
  type        = bool
  description = "Whether public network access is enabled for the Function App."
  default     = null
}

variable "virtual_network_subnet_id" {
  type        = string
  description = "Existing subnet resource ID to use for VNET integration."
  default     = null

  validation {
    condition     = var.virtual_network_subnet_id == null || can(regex("^/subscriptions/[^/]+/resourcegroups/[^/]+/providers/microsoft\\.network/virtualnetworks/[^/]+/subnets/[^/]+$", lower(var.virtual_network_subnet_id)))
    error_message = "virtual_network_subnet_id must be a valid subnet resource ID."
  }
}

variable "maximum_instance_count" {
  type        = number
  description = "Optional maximum scale-out instance count for the Function App."
  default     = null

  validation {
    condition     = var.maximum_instance_count == null || (var.maximum_instance_count >= 1 && var.maximum_instance_count <= 1000)
    error_message = "maximum_instance_count must be between 1 and 1000."
  }
}

variable "instance_memory_in_mb" {
  type        = number
  description = "Optional memory size in MB for Flex Consumption instances. Supported values are 512, 2048, and 4096."
  default     = null

  validation {
    condition     = var.instance_memory_in_mb == null || contains([512, 2048, 4096], var.instance_memory_in_mb)
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
  description = <<DESCRIPTION
Controls Acmebot workload configuration. This object is sensitive because DNS provider credentials, webhook URLs, and external account binding secrets are passed to the Function App as application settings and stored in Terraform state.

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
DESCRIPTION
  nullable    = false
  sensitive   = true

  validation {
    condition     = can(regex("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(\\.(0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?(\\+([0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*))?$", var.acmebot.version))
    error_message = "acmebot.version must be a Semantic Versioning 2.0.0 version, such as 5.0.1, 5.0.1-beta.1, or 5.0.1+build.5."
  }

  validation {
    condition     = var.acmebot.managed_identity_client_id == null || can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.acmebot.managed_identity_client_id))
    error_message = "acmebot.managed_identity_client_id must be a valid GUID."
  }
}
