output "function_app_name" {
  value       = module.acmebot.name
  description = "The name of the Function App."
}

output "function_app_resource_id" {
  value       = module.acmebot.resource_id
  description = "The resource ID of the Function App."
}

output "key_vault_uri" {
  value       = azurerm_key_vault.default.vault_uri
  description = "The URI of the Key Vault where issued certificates are stored."
}

output "user_assigned_identity_principal_id" {
  value       = azurerm_user_assigned_identity.acmebot.principal_id
  description = "The principal ID of the user-assigned identity used by Acmebot and Storage."
}

output "private_endpoints" {
  value       = module.acmebot.private_endpoints
  description = "A map of the Function App private endpoints created by the module."
}

output "storage_account_private_endpoints" {
  value       = module.acmebot.storage_account_private_endpoints
  description = "A map of the Storage Account private endpoints created by the module."
}
