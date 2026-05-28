output "name" {
  value       = module.this.name
  description = "The name of the Function App."
}

output "resource_id" {
  value       = module.this.resource_id
  description = "The resource ID of the Function App."
  sensitive   = true
}

output "resource" {
  value       = module.this.resource
  description = "The Function App resource."
  sensitive   = true
}

output "system_assigned_mi_principal_id" {
  value       = module.this.system_assigned_mi_principal_id
  description = "The principal ID of the system-assigned managed identity. Null when the system-assigned identity is disabled."
  sensitive   = true
}

output "private_endpoints" {
  value = {
    for key, pe in coalesce(module.this.private_endpoints, {}) : key => {
      name        = pe.name
      resource_id = pe.id
    }
  }
  description = "A map of the Function App private endpoints created."
}

output "storage_account_private_endpoints" {
  value = {
    for key, pe in module.storage.private_endpoints : key => {
      name        = pe.name
      resource_id = pe.id
    }
  }
  description = "A map of the Storage Account private endpoints created."
}

output "api_key" {
  value       = var.export_api_key ? data.azapi_resource_action.function_host_keys[0].output.functionKeys.default : null
  description = "Created Default Functions API Key. Null unless export_api_key is enabled."
  sensitive   = true
}
