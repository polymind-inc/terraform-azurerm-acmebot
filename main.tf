data "azurerm_client_config" "current" {}

resource "azurerm_storage_account" "storage" {
  name                = local.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.additional_tags

  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"
}

resource "random_string" "deployment_container_suffix" {
  length  = 7
  lower   = true
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_storage_container" "deployment" {
  name                  = local.deployment_container_name
  storage_account_id    = azurerm_storage_account.storage.id
  container_access_type = "private"
}

resource "azurerm_service_plan" "serverfarm" {
  name                = "plan-${var.app_base_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.additional_tags

  os_type  = "Linux"
  sku_name = "FC1"
}

resource "azurerm_log_analytics_workspace" "workspace" {
  name                = "log-${var.app_base_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.additional_tags

  sku               = "PerGB2018"
  retention_in_days = 30
}

resource "azurerm_application_insights" "insights" {
  name                = "appi-${var.app_base_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.additional_tags

  application_type = "web"
  workspace_id     = azurerm_log_analytics_workspace.workspace.id
}

resource "azurerm_function_app_flex_consumption" "function" {
  name                = local.function_app_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.additional_tags

  service_plan_id               = azurerm_service_plan.serverfarm.id
  storage_container_type        = "blobContainer"
  storage_container_endpoint    = "${azurerm_storage_account.storage.primary_blob_endpoint}${azurerm_storage_container.deployment.name}"
  storage_authentication_type   = "StorageAccountConnectionString"
  storage_access_key            = azurerm_storage_account.storage.primary_access_key
  runtime_name                  = "dotnet-isolated"
  runtime_version               = "10.0"
  https_only                    = true
  public_network_access_enabled = var.public_network_access_enabled
  virtual_network_subnet_id     = local.vnet_integration_subnet_id
  maximum_instance_count        = var.maximum_instance_count
  instance_memory_in_mb         = var.instance_memory_in_mb

  app_settings = merge(var.additional_app_settings, local.acmebot_app_settings, local.auth_app_settings)

  identity {
    type = "SystemAssigned"
  }

  dynamic "auth_settings_v2" {
    for_each = toset(var.auth_settings != null ? [1] : [])

    content {
      auth_enabled           = var.auth_settings.enabled
      default_provider       = "azureactivedirectory"
      require_authentication = true
      unauthenticated_action = "RedirectToLoginPage"

      login {
        token_store_enabled = false
      }

      active_directory_v2 {
        client_id                  = var.auth_settings.active_directory.client_id
        client_secret_setting_name = "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"
        tenant_auth_endpoint       = var.auth_settings.active_directory.tenant_auth_endpoint
      }
    }
  }

  site_config {
    application_insights_connection_string = azurerm_application_insights.insights.connection_string
    minimum_tls_version                    = "1.2"
    scm_minimum_tls_version                = "1.2"
    scm_use_main_ip_restriction            = true

    ip_restriction_default_action = length(var.allowed_ip_addresses) != 0 ? "Deny" : "Allow"

    dynamic "ip_restriction" {
      for_each = var.allowed_ip_addresses

      content {
        ip_address = ip_restriction.value
      }
    }
  }
}

resource "azapi_resource" "deployment" {
  name      = "onedeploy"
  parent_id = azurerm_function_app_flex_consumption.function.id
  type      = "Microsoft.Web/sites/extensions@2025-03-01"

  body = {
    properties = {
      packageUri  = local.acmebot_package_uri
      remoteBuild = false
    }
  }

  schema_validation_enabled = false
}

data "azurerm_function_app_host_keys" "function" {
  count = var.export_api_key ? 1 : 0

  name                = azurerm_function_app_flex_consumption.function.name
  resource_group_name = var.resource_group_name

  depends_on = [
    azurerm_function_app_flex_consumption.function,
    azapi_resource.deployment
  ]
}
