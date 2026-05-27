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
  description = "Authentication settings for the function app"
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
  description = "A map of diagnostic settings to create on the Function App. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time."
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
  description = "A map of private endpoints to create for the Function App. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time."
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
  description = "Additional settings to set for the function app"
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
  description = "App Service site configuration values exposed by this module. The networking and IP restriction fields follow the AVM App Service interface shape."
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
  description = "Controls the Managed Identity configuration on the Function App. Acmebot requires either a system-assigned managed identity or a user-assigned managed identity with acmebot_managed_identity_client_id."
  default     = {}
  nullable    = false

  validation {
    condition = alltrue([
      for resource_id in var.managed_identities.user_assigned_resource_ids : can(regex("^/subscriptions/[^/]+/resourcegroups/[^/]+/providers/microsoft\\.managedidentity/userassignedidentities/[^/]+$", lower(resource_id)))
    ])
    error_message = "managed_identities.user_assigned_resource_ids must contain valid user-assigned managed identity resource IDs."
  }
}

variable "acmebot_managed_identity_client_id" {
  type        = string
  description = "The client ID of the user-assigned managed identity that Acmebot should use. Set this when Acmebot must authenticate with a user-assigned managed identity attached through managed_identities.user_assigned_resource_ids."
  default     = null
  nullable    = true

  validation {
    condition     = var.acmebot_managed_identity_client_id == null || can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.acmebot_managed_identity_client_id))
    error_message = "acmebot_managed_identity_client_id must be a valid GUID."
  }
}

variable "lock" {
  type = object({
    kind = string
    name = optional(string, null)
  })
  description = "Controls the Resource Lock configuration for the Function App. `kind` must be either `CanNotDelete` or `ReadOnly`; `name` is optional."
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
  description = "A map of role assignments to create on the Function App. The map key is deliberately arbitrary to avoid issues where map keys may be unknown at plan time."
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

variable "storage_account_name" {
  type        = string
  description = "Optional explicit storage account name. When unset, the module generates a deterministic globally-unique name."
  default     = null

  validation {
    condition     = var.storage_account_name == null || can(regex("^[a-z0-9]{3,24}$", var.storage_account_name))
    error_message = "storage_account_name must be 3-24 characters of lowercase letters and numbers."
  }
}

variable "service_plan_name" {
  type        = string
  description = "Optional explicit name for the App Service Plan. When unset, the module generates a CAF-aligned name using the asp prefix."
  default     = null

  validation {
    condition     = var.service_plan_name == null || can(regex("^[A-Za-z0-9][A-Za-z0-9-]*[A-Za-z0-9]$", var.service_plan_name))
    error_message = "service_plan_name must contain only letters, numbers, and hyphens, and start and end with a letter or number."
  }
}

variable "log_analytics_workspace_name" {
  type        = string
  description = "Optional explicit name for the Log Analytics workspace. When unset, the module generates a CAF-aligned name using the log prefix."
  default     = null

  validation {
    condition     = var.log_analytics_workspace_name == null || can(regex("^[A-Za-z0-9][A-Za-z0-9-]*[A-Za-z0-9]$", var.log_analytics_workspace_name))
    error_message = "log_analytics_workspace_name must contain only letters, numbers, and hyphens, and start and end with a letter or number."
  }
}

variable "application_insights_name" {
  type        = string
  description = "Optional explicit name for the Application Insights component. When unset, the module generates a CAF-aligned name using the appi prefix."
  default     = null

  validation {
    condition     = var.application_insights_name == null || can(regex("^[A-Za-z0-9][A-Za-z0-9-]*[A-Za-z0-9]$", var.application_insights_name))
    error_message = "application_insights_name must contain only letters, numbers, and hyphens, and start and end with a letter or number."
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
variable "acmebot_version" {
  type        = string
  description = "Acmebot package version to deploy. Must be a Semantic Versioning 2.0.0 version, such as 5.0.1, 5.0.1-beta.1, or 5.0.1+build.5."
  nullable    = false

  validation {
    condition     = can(regex("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)(\\.(0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?(\\+([0-9A-Za-z-]+(\\.[0-9A-Za-z-]+)*))?$", var.acmebot_version))
    error_message = "acmebot_version must be a Semantic Versioning 2.0.0 version, such as 5.0.1, 5.0.1-beta.1, or 5.0.1+build.5."
  }
}

variable "vault_uri" {
  type        = string
  description = "URL of the Key Vault to store the issued certificate."
}

variable "mail_address" {
  type        = string
  description = "Email address for ACME account."
}

variable "acme_endpoint" {
  type        = string
  description = "Certification authority ACME Endpoint."
  default     = "https://acme-v02.api.letsencrypt.org/directory"
}

variable "environment" {
  type        = string
  description = "The name of the Azure environment."
  default     = "AzureCloud"
}

variable "webhook_url" {
  type        = string
  description = "The webhook where notifications will be sent."
  default     = null
  sensitive   = true
}

variable "mitigate_chain_order" {
  type        = bool
  description = "Mitigate certificate ordering issues that occur with some services."
  default     = false
}

variable "app_role_required" {
  type        = bool
  description = "Specify whether additional App Role assignment is required during Azure AD authentication."
  default     = false
}

variable "external_account_binding" {
  type = object({
    key_id    = string
    hmac_key  = string
    algorithm = string
  })
  default   = null
  sensitive = true
}

# DNS Provider Configuration
variable "azure_dns" {
  type = object({
    subscription_id = string
  })
  default = null
}

variable "azure_private_dns" {
  type = object({
    subscription_id = string
  })
  default = null
}

variable "cloudflare" {
  type = object({
    api_token = string
  })
  default   = null
  sensitive = true
}

variable "custom_dns" {
  type = object({
    endpoint            = string
    api_key             = string
    api_key_header_name = string
    propagation_seconds = number
  })
  default   = null
  sensitive = true
}

variable "dns_made_easy" {
  type = object({
    api_key    = string
    secret_key = string
  })
  default   = null
  sensitive = true
}

variable "gandi" {
  type = object({
    api_key = string
  })
  default   = null
  sensitive = true
}

variable "go_daddy" {
  type = object({
    api_key    = string
    api_secret = string
  })
  default   = null
  sensitive = true
}

variable "google_dns" {
  type = object({
    key_file64 = string
  })
  default   = null
  sensitive = true
}

variable "route_53" {
  type = object({
    access_key = string
    secret_key = string
    region     = string
  })
  default   = null
  sensitive = true
}

variable "trans_ip" {
  type = object({
    customer_name    = string
    private_key_name = string
  })
  default = null
}
