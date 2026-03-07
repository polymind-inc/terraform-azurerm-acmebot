output "principal_id" {
  value       = azurerm_function_app_flex_consumption.function.identity[0].principal_id
  description = "Created Managed Identity Principal ID"
}

output "tenant_id" {
  value       = azurerm_function_app_flex_consumption.function.identity[0].tenant_id
  description = "Created Managed Identity Tenant ID"
}

output "allowed_ip_addresses" {
  value       = var.allowed_ip_addresses
  description = "IP addresses that are allowed to access the Acmebot UI."
}

output "api_key" {
  value       = var.export_api_key ? data.azurerm_function_app_host_keys.function[0].default_function_key : null
  description = "Created Default Functions API Key. Null unless export_api_key is enabled."
  sensitive   = true
}
