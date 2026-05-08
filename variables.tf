variable "app_base_name" {
  type        = string
  description = "The name of the App base to create."

  validation {
    condition     = can(regex("^[A-Za-z0-9-]+$", var.app_base_name)) && can(regex("[A-Za-z0-9]$", var.app_base_name)) && length("func-${var.app_base_name}") <= 32
    error_message = "app_base_name must contain only letters, numbers, and hyphens; end with a letter or number; and keep the generated function app name within 32 characters."
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

variable "allowed_ip_addresses" {
  type        = list(string)
  description = "A list of allowed ip addresses that can access the Acmebot UI."
  default     = []
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

variable "additional_tags" {
  type        = map(string)
  description = "Additional tags to set for resources"
  default     = {}
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

variable "public_network_access_enabled" {
  type        = bool
  description = "Whether public network access is enabled for the Function App."
  default     = null
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
  description = "Acmebot package version to deploy. Use a major version like v5 for the latest package, or a specific version like v5.0.1."
  default     = "v5"

  validation {
    condition     = can(regex("^v[0-9]+(\\.[0-9]+\\.[0-9]+)?$", var.acmebot_version))
    error_message = "acmebot_version must be a major version like v5, or a specific version like v5.0.1."
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
