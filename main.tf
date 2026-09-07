resource "random_string" "deployment_container_suffix" {
  length  = 7
  lower   = true
  upper   = false
  numeric = true
  special = false
}

module "storage" {
  source  = "Azure/avm-res-storage-storageaccount/azurerm"
  version = "~> 0.10.0"

  name             = local.storage_account_name
  location         = var.location
  parent_id        = local.resource_group_id
  enable_telemetry = var.enable_telemetry
  tags             = var.storage_account.tags != null ? var.storage_account.tags : var.tags

  account_kind = "StorageV2"
  # account_sku_name is authoritative in the storage AVM module; account_tier /
  # account_replication_type are deprecated there and ignored when it is set.
  account_sku_name                  = local.storage_account_sku_name
  allow_nested_items_to_be_public   = false
  blob_properties                   = var.storage_account.blob_properties
  default_to_oauth_authentication   = var.storage_account.default_to_oauth_authentication
  infrastructure_encryption_enabled = var.storage_account.infrastructure_encryption_enabled
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  network_rules                     = var.storage_account.network_rules
  public_network_access_enabled     = local.storage_public_network_access_enabled
  shared_access_key_enabled         = var.storage_account.shared_access_key_enabled

  containers = {
    deployment = {
      name = local.deployment_container_name
    }
  }

  private_endpoints_manage_dns_zone_group = var.private_endpoints_manage_dns_zone_group

  private_endpoints = {
    for key, pe in var.storage_account.private_endpoints : key => pe
  }

  role_assignments = {}
  lock             = null
}

module "serverfarm" {
  source  = "Azure/avm-res-web-serverfarm/azurerm"
  version = "~> 2.0"

  name             = coalesce(var.service_plan.name, "asp-${var.name}")
  location         = var.location
  parent_id        = local.resource_group_id
  enable_telemetry = var.enable_telemetry
  tags             = var.service_plan.tags != null ? var.service_plan.tags : var.tags

  os_type                = "Linux"
  sku_name               = "FC1"
  zone_balancing_enabled = var.service_plan.zone_redundant
}

resource "azapi_resource" "log_analytics_workspace" {
  count = local.create_log_analytics_workspace ? 1 : 0

  name      = coalesce(var.log_analytics_workspace.name, "log-${var.name}")
  location  = var.location
  parent_id = local.resource_group_id
  type      = "Microsoft.OperationalInsights/workspaces@2025-02-01"
  tags      = var.log_analytics_workspace.tags != null ? var.log_analytics_workspace.tags : var.tags

  body = {
    properties = {
      retentionInDays = var.log_analytics_workspace.retention_in_days
      sku = {
        name = "PerGB2018"
      }
    }
  }

  response_export_values = []
}

resource "azapi_resource" "application_insights" {
  count = local.create_application_insights ? 1 : 0

  name      = coalesce(var.application_insights.name, "appi-${var.name}")
  location  = var.location
  parent_id = local.resource_group_id
  type      = "Microsoft.Insights/components@2020-02-02"
  tags      = var.application_insights.tags != null ? var.application_insights.tags : var.tags

  body = {
    kind = "web"
    properties = {
      Application_Type    = "web"
      WorkspaceResourceId = local.log_analytics_workspace_resource_id
    }
  }

  response_export_values = ["properties.ConnectionString", "properties.InstrumentationKey"]
}

data "azapi_resource" "application_insights" {
  count = local.create_application_insights ? 0 : 1

  type                   = "Microsoft.Insights/components@2020-02-02"
  resource_id            = var.application_insights.resource_id
  response_export_values = ["properties.ConnectionString", "properties.InstrumentationKey", "properties.WorkspaceResourceId"]
}

module "this" {
  source  = "Azure/avm-res-web-site/azurerm"
  version = "~> 0.22.0"

  name             = var.name
  location         = var.location
  parent_id        = local.resource_group_id
  enable_telemetry = var.enable_telemetry
  tags             = var.tags

  kind                     = "functionapp"
  os_type                  = "Linux"
  service_plan_resource_id = module.serverfarm.resource_id

  function_app_uses_fc1  = true
  fc1_runtime_name       = "dotnet-isolated"
  fc1_runtime_version    = "10.0"
  instance_memory_in_mb  = var.instance_memory_in_mb
  maximum_instance_count = var.maximum_instance_count

  https_only                    = true
  public_network_access_enabled = local.function_public_network_access_enabled
  virtual_network_subnet_id     = var.virtual_network_subnet_id

  storage_account_name              = local.storage_account_name
  storage_container_type            = "blobContainer"
  storage_container_endpoint        = local.storage_container_endpoint_url
  storage_authentication_type       = local.storage_authentication_type
  storage_user_assigned_identity_id = var.storage_managed_identity.user_assigned_resource_id
  storage_uses_managed_identity     = true

  application_insights_connection_string = local.application_insights_connection_string
  application_insights_key               = local.application_insights_instrumentation_key

  app_settings = local.function_app_settings

  managed_identities = {
    system_assigned            = var.managed_identities.system_assigned
    user_assigned_resource_ids = var.managed_identities.user_assigned_resource_ids
  }

  auth_settings_v2 = local.auth_settings_v2

  site_config = {
    minimum_tls_version               = "1.2"
    scm_minimum_tls_version           = "1.2"
    ftps_state                        = "Disabled"
    scm_use_main_ip_restriction       = local.site_config_scm_use_main_ip_restriction
    vnet_route_all_enabled            = local.site_config_vnet_route_all_enabled
    ip_restriction_default_action     = local.site_config_ip_restriction_default_action
    scm_ip_restriction_default_action = local.site_config_scm_ip_restriction_default_action
    ip_restriction                    = var.site_config.ip_restriction
    scm_ip_restriction                = var.site_config.scm_ip_restriction
  }

  private_endpoints_manage_dns_zone_group = var.private_endpoints_manage_dns_zone_group
  private_endpoints_inherit_lock          = true
  private_endpoints                       = var.private_endpoints

  role_assignments = var.role_assignments
  lock             = var.lock

  depends_on = [
    module.storage,
  ]
}

data "azapi_resource" "storage_user_assigned_identity" {
  count = local.storage_uses_user_assigned_identity ? 1 : 0

  type                   = "Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31"
  resource_id            = var.storage_managed_identity.user_assigned_resource_id
  response_export_values = ["properties.clientId", "properties.principalId"]
}

resource "azapi_resource" "storage_account_function_app_role_assignment" {
  for_each = local.storage_role_definition_ids

  name      = uuidv5("url", "${module.storage.resource_id}/roleAssignments/${each.key}/${local.storage_managed_identity_principal_id}")
  parent_id = module.storage.resource_id
  type      = "Microsoft.Authorization/roleAssignments@2022-04-01"

  body = {
    properties = {
      principalId      = local.storage_managed_identity_principal_id
      principalType    = "ServicePrincipal"
      roleDefinitionId = each.value
    }
  }

  ignore_null_property   = true
  response_export_values = []
}

moved {
  from = azapi_resource.deployment
  to   = azapi_resource.deployment[0]
}

resource "azapi_resource" "deployment" {
  count = var.skip_package_deployment ? 0 : 1

  name      = "onedeploy"
  parent_id = module.this.resource_id
  type      = "Microsoft.Web/sites/extensions@2025-03-01"

  body = {
    properties = {
      type        = "zip"
      packageUri  = local.acmebot_package_uri
      remoteBuild = false
    }
  }

  schema_validation_enabled = false

  depends_on = [
    azapi_resource.storage_account_function_app_role_assignment,
  ]
}

data "azapi_resource_action" "function_host_keys" {
  count = var.export_api_key ? 1 : 0

  type                   = "Microsoft.Web/sites/host@2025-03-01"
  resource_id            = "${module.this.resource_id}/host/default"
  action                 = "listKeys"
  method                 = "POST"
  response_export_values = ["functionKeys"]

  depends_on = [
    azapi_resource.deployment,
  ]
}
