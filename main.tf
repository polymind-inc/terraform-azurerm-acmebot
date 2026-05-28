data "azurerm_client_config" "current" {}

resource "azurerm_storage_account" "storage" {
  name                = local.storage_account_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.storage_account.tags != null ? var.storage_account.tags : local.tags

  account_kind                    = "StorageV2"
  account_tier                    = "Standard"
  account_replication_type        = var.storage_account.account_replication_type
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
  name                  = coalesce(var.deployment_container.name, local.deployment_container_name)
  storage_account_id    = azurerm_storage_account.storage.id
  container_access_type = "private"
}

resource "azurerm_service_plan" "serverfarm" {
  name                = coalesce(var.service_plan.name, "asp-${var.name}")
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.service_plan.tags != null ? var.service_plan.tags : local.tags

  os_type  = "Linux"
  sku_name = "FC1"
}

resource "azurerm_log_analytics_workspace" "workspace" {
  name                = coalesce(var.log_analytics_workspace.name, "log-${var.name}")
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.log_analytics_workspace.tags != null ? var.log_analytics_workspace.tags : local.tags

  sku               = "PerGB2018"
  retention_in_days = var.log_analytics_workspace.retention_in_days
}

resource "azurerm_application_insights" "insights" {
  name                = coalesce(var.application_insights.name, "appi-${var.name}")
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.application_insights.tags != null ? var.application_insights.tags : local.tags

  application_type = "web"
  workspace_id     = azurerm_log_analytics_workspace.workspace.id
}

resource "azurerm_function_app_flex_consumption" "function" {
  name                = local.function_app_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = local.tags

  service_plan_id               = azurerm_service_plan.serverfarm.id
  storage_container_type        = "blobContainer"
  storage_container_endpoint    = "${azurerm_storage_account.storage.primary_blob_endpoint}${azurerm_storage_container.deployment.name}"
  storage_authentication_type   = "StorageAccountConnectionString"
  storage_access_key            = azurerm_storage_account.storage.primary_access_key
  runtime_name                  = "dotnet-isolated"
  runtime_version               = "10.0"
  https_only                    = true
  public_network_access_enabled = var.public_network_access_enabled
  virtual_network_subnet_id     = var.virtual_network_subnet_id
  maximum_instance_count        = var.maximum_instance_count
  instance_memory_in_mb         = var.instance_memory_in_mb

  app_settings = merge(var.additional_app_settings, local.acmebot_app_settings, local.auth_app_settings)

  dynamic "identity" {
    for_each = local.managed_identities.system_assigned_user_assigned

    content {
      type         = identity.value.type
      identity_ids = length(identity.value.user_assigned_resource_ids) > 0 ? identity.value.user_assigned_resource_ids : null
    }
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
    scm_use_main_ip_restriction            = var.site_config.scm_use_main_ip_restriction
    vnet_route_all_enabled                 = var.site_config.vnet_route_all_enabled

    ip_restriction_default_action     = var.site_config.ip_restriction_default_action
    scm_ip_restriction_default_action = var.site_config.scm_ip_restriction_default_action

    dynamic "ip_restriction" {
      for_each = var.site_config.ip_restriction

      content {
        action                    = ip_restriction.value.action
        ip_address                = ip_restriction.value.ip_address
        name                      = ip_restriction.value.name
        priority                  = ip_restriction.value.priority
        service_tag               = ip_restriction.value.service_tag
        virtual_network_subnet_id = ip_restriction.value.virtual_network_subnet_id

        dynamic "headers" {
          for_each = ip_restriction.value.headers != null ? [ip_restriction.value.headers] : []

          content {
            x_azure_fdid      = headers.value.x_azure_fdid
            x_fd_health_probe = headers.value.x_fd_health_probe
            x_forwarded_for   = headers.value.x_forwarded_for
            x_forwarded_host  = headers.value.x_forwarded_host
          }
        }
      }
    }

    dynamic "scm_ip_restriction" {
      for_each = var.site_config.scm_ip_restriction

      content {
        action                    = scm_ip_restriction.value.action
        ip_address                = scm_ip_restriction.value.ip_address
        name                      = scm_ip_restriction.value.name
        priority                  = scm_ip_restriction.value.priority
        service_tag               = scm_ip_restriction.value.service_tag
        virtual_network_subnet_id = scm_ip_restriction.value.virtual_network_subnet_id

        dynamic "headers" {
          for_each = scm_ip_restriction.value.headers != null ? [scm_ip_restriction.value.headers] : []

          content {
            x_azure_fdid      = headers.value.x_azure_fdid
            x_fd_health_probe = headers.value.x_fd_health_probe
            x_forwarded_for   = headers.value.x_forwarded_for
            x_forwarded_host  = headers.value.x_forwarded_host
          }
        }
      }
    }
  }

  lifecycle {
    precondition {
      condition     = var.managed_identities.system_assigned || var.acmebot.managed_identity_client_id != null
      error_message = "acmebot.managed_identity_client_id must be set when managed_identities.system_assigned is false so Acmebot can authenticate with the attached user-assigned managed identity."
    }

    precondition {
      condition     = var.acmebot.managed_identity_client_id == null || length(var.managed_identities.user_assigned_resource_ids) > 0
      error_message = "acmebot.managed_identity_client_id can only be set when at least one user-assigned managed identity is attached through managed_identities.user_assigned_resource_ids."
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "function_app" {
  for_each = var.diagnostic_settings

  name                           = each.value.name != null ? each.value.name : "diag-${local.function_app_name}"
  target_resource_id             = azurerm_function_app_flex_consumption.function.id
  eventhub_authorization_rule_id = each.value.event_hub_authorization_rule_resource_id
  eventhub_name                  = each.value.event_hub_name
  log_analytics_destination_type = each.value.log_analytics_destination_type
  log_analytics_workspace_id     = each.value.workspace_resource_id
  partner_solution_id            = each.value.marketplace_partner_resource_id
  storage_account_id             = each.value.storage_account_resource_id

  dynamic "enabled_log" {
    for_each = each.value.log_categories

    content {
      category = enabled_log.value
    }
  }

  dynamic "enabled_log" {
    for_each = each.value.log_groups

    content {
      category_group = enabled_log.value
    }
  }

  dynamic "enabled_metric" {
    for_each = each.value.metric_categories

    content {
      category = enabled_metric.value
    }
  }
}

resource "azurerm_private_endpoint" "function_app" {
  for_each = {
    for key, private_endpoint in var.private_endpoints : key => private_endpoint
    if var.private_endpoints_manage_dns_zone_group
  }

  name                          = coalesce(each.value.name, "pep-${local.function_app_name}-${each.key}")
  resource_group_name           = coalesce(each.value.resource_group_name, var.resource_group_name)
  location                      = coalesce(each.value.location, var.location)
  subnet_id                     = each.value.subnet_resource_id
  custom_network_interface_name = each.value.network_interface_name
  tags                          = each.value.tags != null ? each.value.tags : local.tags

  private_service_connection {
    name                           = coalesce(each.value.private_service_connection_name, "psc-${local.function_app_name}-${each.key}")
    private_connection_resource_id = azurerm_function_app_flex_consumption.function.id
    is_manual_connection           = false
    subresource_names              = [each.value.subresource_name]
  }

  dynamic "private_dns_zone_group" {
    for_each = var.private_endpoints_manage_dns_zone_group && length(each.value.private_dns_zone_resource_ids) > 0 ? [each.value] : []

    content {
      name                 = private_dns_zone_group.value.private_dns_zone_group_name
      private_dns_zone_ids = private_dns_zone_group.value.private_dns_zone_resource_ids
    }
  }

  dynamic "ip_configuration" {
    for_each = each.value.ip_configurations

    content {
      name               = ip_configuration.value.name
      private_ip_address = ip_configuration.value.private_ip_address
      member_name        = coalesce(ip_configuration.value.member_name, each.value.subresource_name)
      subresource_name   = each.value.subresource_name
    }
  }
}

resource "azurerm_private_endpoint" "function_app_unmanaged_dns_zone_groups" {
  for_each = {
    for key, private_endpoint in var.private_endpoints : key => private_endpoint
    if !var.private_endpoints_manage_dns_zone_group
  }

  name                          = coalesce(each.value.name, "pep-${local.function_app_name}-${each.key}")
  resource_group_name           = coalesce(each.value.resource_group_name, var.resource_group_name)
  location                      = coalesce(each.value.location, var.location)
  subnet_id                     = each.value.subnet_resource_id
  custom_network_interface_name = each.value.network_interface_name
  tags                          = each.value.tags != null ? each.value.tags : local.tags

  private_service_connection {
    name                           = coalesce(each.value.private_service_connection_name, "psc-${local.function_app_name}-${each.key}")
    private_connection_resource_id = azurerm_function_app_flex_consumption.function.id
    is_manual_connection           = false
    subresource_names              = [each.value.subresource_name]
  }

  dynamic "ip_configuration" {
    for_each = each.value.ip_configurations

    content {
      name               = ip_configuration.value.name
      private_ip_address = ip_configuration.value.private_ip_address
      member_name        = coalesce(ip_configuration.value.member_name, each.value.subresource_name)
      subresource_name   = each.value.subresource_name
    }
  }

  lifecycle {
    ignore_changes = [private_dns_zone_group]
  }
}

resource "azurerm_private_endpoint_application_security_group_association" "function_app" {
  for_each = local.private_endpoint_application_security_group_associations

  private_endpoint_id           = local.private_endpoint_resource_ids[each.value.private_endpoint_key]
  application_security_group_id = each.value.application_security_group_resource_id
}

resource "azurerm_role_assignment" "function_app" {
  for_each = var.role_assignments

  scope                                  = azurerm_function_app_flex_consumption.function.id
  role_definition_id                     = length(regexall(local.role_definition_resource_substring, lower(each.value.role_definition_id_or_name))) > 0 ? each.value.role_definition_id_or_name : null
  role_definition_name                   = length(regexall(local.role_definition_resource_substring, lower(each.value.role_definition_id_or_name))) > 0 ? null : each.value.role_definition_id_or_name
  principal_id                           = each.value.principal_id
  description                            = each.value.description
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  principal_type                         = each.value.principal_type
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}

resource "azurerm_management_lock" "function_app" {
  count = var.lock != null ? 1 : 0

  name       = coalesce(var.lock.name, "lock-${var.lock.kind}")
  scope      = azurerm_function_app_flex_consumption.function.id
  lock_level = var.lock.kind
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the Function App or its child resources." : "Cannot delete or modify the Function App or its child resources."

  depends_on = [
    azapi_resource.deployment,
    azurerm_role_assignment.function_app
  ]
}

resource "azurerm_role_assignment" "private_endpoint" {
  for_each = local.private_endpoint_role_assignments

  scope                                  = local.private_endpoint_resource_ids[each.value.private_endpoint_key]
  role_definition_id                     = length(regexall(local.role_definition_resource_substring, lower(each.value.role_definition_id_or_name))) > 0 ? each.value.role_definition_id_or_name : null
  role_definition_name                   = length(regexall(local.role_definition_resource_substring, lower(each.value.role_definition_id_or_name))) > 0 ? null : each.value.role_definition_id_or_name
  principal_id                           = each.value.principal_id
  description                            = each.value.description
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  principal_type                         = each.value.principal_type
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}

resource "azurerm_management_lock" "private_endpoint" {
  for_each = local.private_endpoint_locks

  name       = coalesce(each.value.name, "lock-${each.value.kind}")
  scope      = local.private_endpoint_resource_ids[each.key]
  lock_level = each.value.kind
  notes      = each.value.kind == "CanNotDelete" ? "Cannot delete the private endpoint or its child resources." : "Cannot delete or modify the private endpoint or its child resources."

  depends_on = [
    azurerm_private_endpoint_application_security_group_association.function_app,
    azurerm_role_assignment.private_endpoint
  ]
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
