output "name" {
  value       = azurerm_function_app_flex_consumption.function.name
  description = "The name of the Function App."
}

output "resource_id" {
  value       = azurerm_function_app_flex_consumption.function.id
  description = "The resource ID of the Function App."
}

output "system_assigned_mi_principal_id" {
  value       = try(azurerm_function_app_flex_consumption.function.identity[0].principal_id, null)
  description = "The principal ID of the system-assigned managed identity."
}

output "system_assigned_mi_tenant_id" {
  value       = try(azurerm_function_app_flex_consumption.function.identity[0].tenant_id, null)
  description = "The tenant ID of the system-assigned managed identity."
}

output "private_endpoints" {
  value = {
    for key in keys(local.private_endpoint_resource_ids) : key => {
      name        = local.private_endpoint_names[key]
      resource_id = local.private_endpoint_resource_ids[key]
    }
  }
  description = "A map of the private endpoints created."
}

output "private_endpoint_resource_ids" {
  value       = local.private_endpoint_resource_ids
  description = "The resource IDs of the private endpoints."
}

output "private_endpoint_names" {
  value       = local.private_endpoint_names
  description = "The names of the private endpoints."
}

output "api_key" {
  value       = var.export_api_key ? data.azurerm_function_app_host_keys.function[0].default_function_key : null
  description = "Created Default Functions API Key. Null unless export_api_key is enabled."
  sensitive   = true
}
