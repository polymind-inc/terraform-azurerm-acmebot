data "azapi_client_config" "current" {}

resource "random_string" "deployment_container_suffix" {
  length  = 7
  lower   = true
  upper   = false
  numeric = true
  special = false
}

module "storage" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "~> 0.7"

  name             = local.storage_account_name
  location         = var.location
  parent_id        = local.resource_group_id
  enable_telemetry = var.enable_telemetry
  tags             = var.storage_account.tags != null ? var.storage_account.tags : local.tags

  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = var.storage_account.account_replication_type
  account_sku_name                = local.storage_account_sku_name
  allow_nested_items_to_be_public = false
  min_tls_version                 = "TLS1_2"
  https_traffic_only_enabled      = true
  public_network_access_enabled   = coalesce(var.storage_account.public_network_access_enabled, true)

  containers = {
    deployment = {
      name = local.deployment_container_name
    }
  }

  private_endpoints_manage_dns_zone_group = var.private_endpoints_manage_dns_zone_group

  private_endpoints = {
    for key, pe in var.storage_account.private_endpoints : key => merge(pe, {
      lock = pe.lock != null ? pe.lock : var.lock
    })
  }

  role_assignments = local.storage_account_role_assignments
}

module "serverfarm" {
  source  = "Azure/avm-res-web-serverfarm/azurerm"
  version = "~> 2.0"

  name             = coalesce(var.service_plan.name, "asp-${var.name}")
  location         = var.location
  parent_id        = local.resource_group_id
  enable_telemetry = var.enable_telemetry
  tags             = var.service_plan.tags != null ? var.service_plan.tags : local.tags

  os_type  = "Linux"
  sku_name = "FC1"
}

module "workspace" {
  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "~> 0.5"

  name                = coalesce(var.log_analytics_workspace.name, "log-${var.name}")
  location            = var.location
  resource_group_name = var.resource_group_name
  enable_telemetry    = var.enable_telemetry
  tags                = var.log_analytics_workspace.tags != null ? var.log_analytics_workspace.tags : local.tags

  log_analytics_workspace_sku               = "PerGB2018"
  log_analytics_workspace_retention_in_days = var.log_analytics_workspace.retention_in_days
}

module "insights" {
  source  = "Azure/avm-res-insights-component/azurerm"
  version = "~> 0.4"

  name                = coalesce(var.application_insights.name, "appi-${var.name}")
  location            = var.location
  resource_group_name = var.resource_group_name
  enable_telemetry    = var.enable_telemetry
  tags                = var.application_insights.tags != null ? var.application_insights.tags : local.tags

  application_type = "web"
  workspace_id     = module.workspace.resource_id
}

module "this" {
  source  = "Azure/avm-res-web-site/azurerm"
  version = "~> 0.22"

  name             = local.function_app_name
  location         = var.location
  parent_id        = local.resource_group_id
  enable_telemetry = var.enable_telemetry
  tags             = local.tags

  kind                     = "functionapp"
  os_type                  = "Linux"
  service_plan_resource_id = module.serverfarm.resource_id

  function_app_uses_fc1  = true
  fc1_runtime_name       = "dotnet-isolated"
  fc1_runtime_version    = "10.0"
  instance_memory_in_mb  = coalesce(var.instance_memory_in_mb, 2048)
  maximum_instance_count = var.maximum_instance_count

  https_only                    = true
  public_network_access_enabled = coalesce(var.public_network_access_enabled, true)
  virtual_network_subnet_id     = var.virtual_network_subnet_id

  storage_account_name          = local.storage_account_name
  storage_container_type        = "blobContainer"
  storage_container_endpoint    = local.storage_container_endpoint_url
  storage_authentication_type   = "SystemAssignedIdentity"
  storage_uses_managed_identity = true

  application_insights_connection_string = module.insights.connection_string
  application_insights_key               = module.insights.instrumentation_key

  app_settings = local.function_app_settings

  managed_identities = {
    system_assigned            = var.managed_identities.system_assigned
    user_assigned_resource_ids = var.managed_identities.user_assigned_resource_ids
  }

  auth_settings_v2 = local.auth_settings_v2

  site_config = {
    minimum_tls_version               = "1.2"
    scm_minimum_tls_version           = "1.2"
    scm_use_main_ip_restriction       = var.site_config.scm_use_main_ip_restriction
    vnet_route_all_enabled            = var.site_config.vnet_route_all_enabled
    ip_restriction_default_action     = var.site_config.ip_restriction_default_action
    scm_ip_restriction_default_action = var.site_config.scm_ip_restriction_default_action
    ip_restriction                    = var.site_config.ip_restriction
    scm_ip_restriction                = var.site_config.scm_ip_restriction
  }

  private_endpoints_manage_dns_zone_group = var.private_endpoints_manage_dns_zone_group
  private_endpoints_inherit_lock          = true
  private_endpoints                       = var.private_endpoints

  role_assignments    = var.role_assignments
  diagnostic_settings = var.diagnostic_settings
  lock                = var.lock
}

resource "azapi_resource" "deployment" {
  name      = "onedeploy"
  parent_id = module.this.resource_id
  type      = "Microsoft.Web/sites/extensions@2025-03-01"

  body = {
    properties = {
      packageUri  = local.acmebot_package_uri
      remoteBuild = false
    }
  }

  schema_validation_enabled = false

  depends_on = [
    module.storage,
  ]
}

data "azapi_resource_action" "function_host_keys" {
  count = var.export_api_key ? 1 : 0

  type                   = "Microsoft.Web/sites/host@2024-04-01"
  resource_id            = "${module.this.resource_id}/host/default"
  action                 = "listKeys"
  method                 = "POST"
  response_export_values = ["functionKeys"]

  depends_on = [
    azapi_resource.deployment,
  ]
}

check "auth_settings_secret" {
  assert {
    condition     = var.auth_settings == null || var.auth_settings_client_secret != null
    error_message = "auth_settings_client_secret must be set when auth_settings is configured."
  }
}

check "managed_identity" {
  assert {
    condition     = var.managed_identities.system_assigned == true
    error_message = "managed_identities.system_assigned must be true because the Function App uses its system-assigned managed identity to access the deployment storage account."
  }

  assert {
    condition     = var.managed_identities.system_assigned || var.acmebot.managed_identity_client_id != null
    error_message = "acmebot.managed_identity_client_id must be set when managed_identities.system_assigned is false so Acmebot can authenticate with the attached user-assigned managed identity."
  }

  assert {
    condition     = var.acmebot.managed_identity_client_id == null || length(var.managed_identities.user_assigned_resource_ids) > 0
    error_message = "acmebot.managed_identity_client_id can only be set when at least one user-assigned managed identity is attached through managed_identities.user_assigned_resource_ids."
  }
}

check "storage_private_endpoints" {
  assert {
    condition     = length(var.storage_account.private_endpoints) == 0 || var.virtual_network_subnet_id != null
    error_message = "virtual_network_subnet_id must be set when storage_account.private_endpoints is set so the Function App can route Storage Account traffic through the virtual network."
  }

  assert {
    condition     = var.virtual_network_subnet_id == null || length(var.storage_account.private_endpoints) > 0
    error_message = "storage_account.private_endpoints must be set when virtual_network_subnet_id is set so the Function App can access its Storage Account through Private Endpoint."
  }

  assert {
    condition = var.virtual_network_subnet_id == null ? true : alltrue([
      for private_endpoint in values(var.storage_account.private_endpoints) : lower(private_endpoint.subnet_resource_id) != lower(var.virtual_network_subnet_id)
    ])
    error_message = "storage_account.private_endpoints[*].subnet_resource_id must be different from virtual_network_subnet_id because the Flex Consumption VNET integration subnet cannot be used for private endpoints."
  }
}
