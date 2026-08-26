locals {
  resource_group           = provider::azapi::parse_resource_id("Microsoft.Resources/resourceGroups", var.parent_id)
  resource_group_id        = local.resource_group.id
  subscription_id          = local.resource_group.subscription_id
  resource_group_name      = local.resource_group.name
  subscription_resource_id = "/subscriptions/${local.subscription_id}"

  function_public_network_access_enabled = coalesce(var.public_network_access_enabled, false)
  storage_public_network_access_enabled  = coalesce(var.storage_account.public_network_access_enabled, false)

  site_config_ip_restriction_default_action     = coalesce(var.site_config.ip_restriction_default_action, "Deny")
  site_config_scm_ip_restriction_default_action = coalesce(var.site_config.scm_ip_restriction_default_action, "Deny")
  site_config_scm_use_main_ip_restriction       = coalesce(var.site_config.scm_use_main_ip_restriction, true)
  site_config_vnet_route_all_enabled            = coalesce(var.site_config.vnet_route_all_enabled, var.virtual_network_subnet_id != null)

  storage_uses_user_assigned_identity = var.managed_identities.system_assigned == false ? true : var.storage_managed_identity.user_assigned_resource_id != null
  storage_authentication_type         = local.storage_uses_user_assigned_identity ? "UserAssignedIdentity" : "SystemAssignedIdentity"
  storage_managed_identity_client_id  = local.storage_uses_user_assigned_identity ? data.azapi_resource.storage_user_assigned_identity[0].output.properties.clientId : null
  storage_managed_identity_principal_id = local.storage_uses_user_assigned_identity ? (
    data.azapi_resource.storage_user_assigned_identity[0].output.properties.principalId
  ) : nonsensitive(module.this.system_assigned_mi_principal_id)

  storage_account_name = coalesce(
    var.storage_account.name,
    format(
      "st%s%s",
      substr(replace(lower(var.name), "/[^a-z0-9]/", ""), 0, 16),
      substr(md5("${local.subscription_id}/${local.resource_group_name}/${var.name}"), 0, 6),
    )
  )

  deployment_container_name = coalesce(
    var.deployment_container.name,
    format(
      "app-package-%s-%s",
      trim(substr(replace(replace(lower(var.name), "/[^a-z0-9-]/", ""), "/-+/", "-"), 0, 43), "-"),
      random_string.deployment_container_suffix.result,
    )
  )

  # Reads the blob/queue/table service URIs straight from the deployed account so
  # sovereign-cloud endpoint suffixes are honored without hard-coding them. This
  # relies on the storage AVM module exporting properties.primaryEndpoints in its
  # response_export_values; the version pin in main.tf guards against that export
  # changing under us. The storage module's fqdn output is not a substitute: it
  # only covers services that have child resources (blob only here) and hard-codes
  # the core.windows.net suffix.
  storage_primary_endpoints      = nonsensitive(module.storage.resource.output.properties.primaryEndpoints)
  storage_container_endpoint_url = "${local.storage_primary_endpoints.blob}${local.deployment_container_name}"

  acmebot_package_uri = "https://github.com/polymind-inc/acmebot/releases/download/v${var.acmebot.version}/acmebot.zip"

  create_application_insights = coalesce(
    var.application_insights.create,
    var.application_insights.resource_id == null,
  )
  create_log_analytics_workspace = local.create_application_insights ? var.log_analytics_workspace.resource_id == null : false
  log_analytics_workspace_resource_id = (
    var.log_analytics_workspace.resource_id != null ? var.log_analytics_workspace.resource_id :
    local.create_log_analytics_workspace ? azapi_resource.log_analytics_workspace[0].id :
    data.azapi_resource.application_insights[0].output.properties.WorkspaceResourceId
  )
  application_insights_connection_string   = local.create_application_insights ? azapi_resource.application_insights[0].output.properties.ConnectionString : data.azapi_resource.application_insights[0].output.properties.ConnectionString
  application_insights_instrumentation_key = local.create_application_insights ? azapi_resource.application_insights[0].output.properties.InstrumentationKey : data.azapi_resource.application_insights[0].output.properties.InstrumentationKey

  acmebot_use_system_name_server = var.acmebot.use_system_name_server != null ? var.acmebot.use_system_name_server : (
    var.virtual_network_subnet_id != null || var.acmebot.environment != "AzureCloud"
  )

  acmebot_app_settings = merge(
    {
      "Acmebot__Contacts"            = var.acmebot.mail_address
      "Acmebot__Endpoint"            = var.acmebot.acme_endpoint
      "Acmebot__VaultBaseUrl"        = var.acmebot.vault_uri
      "Acmebot__Environment"         = var.acmebot.environment
      "Acmebot__RenewBeforeExpiry"   = tostring(var.acmebot.renew_before_expiry)
      "Acmebot__UseSystemNameServer" = tostring(local.acmebot_use_system_name_server)
      "Acmebot__RequireAppRoles"     = tostring(var.acmebot.app_role_required)
    },
    var.acmebot.external_account_binding != null ? {
      "Acmebot__ExternalAccountBinding__KeyId"     = var.acmebot.external_account_binding.key_id
      "Acmebot__ExternalAccountBinding__HmacKey"   = var.acmebot.external_account_binding.hmac_key
      "Acmebot__ExternalAccountBinding__Algorithm" = var.acmebot.external_account_binding.algorithm
    } : {},
    var.acmebot.dns_providers.akamai != null ? {
      "Acmebot__Akamai__Host"         = var.acmebot.dns_providers.akamai.host
      "Acmebot__Akamai__ClientToken"  = var.acmebot.dns_providers.akamai.client_token
      "Acmebot__Akamai__ClientSecret" = var.acmebot.dns_providers.akamai.client_secret
      "Acmebot__Akamai__AccessToken"  = var.acmebot.dns_providers.akamai.access_token
    } : {},
    var.acmebot.dns_providers.azure_dns != null ? {
      "Acmebot__AzureDns__SubscriptionId" = var.acmebot.dns_providers.azure_dns.subscription_id
    } : {},
    var.acmebot.dns_providers.azure_private_dns != null ? {
      "Acmebot__AzurePrivateDns__SubscriptionId" = var.acmebot.dns_providers.azure_private_dns.subscription_id
    } : {},
    var.acmebot.dns_providers.cloudflare != null ? {
      "Acmebot__Cloudflare__ApiToken" = var.acmebot.dns_providers.cloudflare.api_token
    } : {},
    var.acmebot.dns_providers.custom_dns != null ? {
      "Acmebot__CustomDns__Endpoint"           = var.acmebot.dns_providers.custom_dns.endpoint
      "Acmebot__CustomDns__ApiKey"             = var.acmebot.dns_providers.custom_dns.api_key
      "Acmebot__CustomDns__ApiKeyHeaderName"   = var.acmebot.dns_providers.custom_dns.api_key_header_name
      "Acmebot__CustomDns__PropagationSeconds" = var.acmebot.dns_providers.custom_dns.propagation_seconds
    } : {},
    var.acmebot.dns_providers.dns_made_easy != null ? {
      "Acmebot__DnsMadeEasy__ApiKey"    = var.acmebot.dns_providers.dns_made_easy.api_key
      "Acmebot__DnsMadeEasy__SecretKey" = var.acmebot.dns_providers.dns_made_easy.secret_key
    } : {},
    var.acmebot.dns_providers.gandi_live_dns != null ? {
      "Acmebot__GandiLiveDns__ApiKey" = var.acmebot.dns_providers.gandi_live_dns.api_key
    } : {},
    var.acmebot.dns_providers.go_daddy != null ? {
      "Acmebot__GoDaddy__ApiKey"    = var.acmebot.dns_providers.go_daddy.api_key
      "Acmebot__GoDaddy__ApiSecret" = var.acmebot.dns_providers.go_daddy.api_secret
    } : {},
    var.acmebot.dns_providers.google_dns != null ? {
      "Acmebot__GoogleDns__KeyFile64" = var.acmebot.dns_providers.google_dns.key_file64
    } : {},
    var.acmebot.dns_providers.ionos_dns != null ? {
      "Acmebot__IonosDns__ApiKey" = var.acmebot.dns_providers.ionos_dns.api_key
    } : {},
    var.acmebot.dns_providers.ovh != null ? {
      "Acmebot__Ovh__Endpoint"          = var.acmebot.dns_providers.ovh.endpoint
      "Acmebot__Ovh__ApplicationKey"    = var.acmebot.dns_providers.ovh.application_key
      "Acmebot__Ovh__ApplicationSecret" = var.acmebot.dns_providers.ovh.application_secret
      "Acmebot__Ovh__ConsumerKey"       = var.acmebot.dns_providers.ovh.consumer_key
    } : {},
    var.acmebot.dns_providers.power_dns != null ? {
      "Acmebot__PowerDns__Endpoint" = var.acmebot.dns_providers.power_dns.endpoint
      "Acmebot__PowerDns__ApiKey"   = var.acmebot.dns_providers.power_dns.api_key
      "Acmebot__PowerDns__ServerId" = var.acmebot.dns_providers.power_dns.server_id
    } : {},
    var.acmebot.dns_providers.regfish != null ? {
      "Acmebot__Regfish__ApiKey" = var.acmebot.dns_providers.regfish.api_key
    } : {},
    var.acmebot.dns_providers.route_53 != null ? {
      "Acmebot__Route53__AccessKey" = var.acmebot.dns_providers.route_53.access_key
      "Acmebot__Route53__SecretKey" = var.acmebot.dns_providers.route_53.secret_key
      "Acmebot__Route53__Region"    = var.acmebot.dns_providers.route_53.region
    } : {},
    var.acmebot.dns_providers.trans_ip != null ? {
      "Acmebot__TransIp__CustomerName"   = var.acmebot.dns_providers.trans_ip.customer_name
      "Acmebot__TransIp__PrivateKeyName" = var.acmebot.dns_providers.trans_ip.private_key_name
    } : {},
    var.acmebot.dns_providers.united_domains != null ? {
      "Acmebot__UnitedDomains__ApiKey" = var.acmebot.dns_providers.united_domains.api_key
    } : {},
    var.acmebot.webhook_url != null ? {
      "Acmebot__Webhook" = var.acmebot.webhook_url
    } : {},
    var.acmebot.preferred_chain != null ? {
      "Acmebot__PreferredChain" = var.acmebot.preferred_chain
    } : {},
    var.acmebot.preferred_profile != null ? {
      "Acmebot__PreferredProfile" = var.acmebot.preferred_profile
    } : {},
    var.acmebot.managed_identity_client_id != null ? {
      "Acmebot__ManagedIdentityClientId" = var.acmebot.managed_identity_client_id
    } : {},
  )

  auth_app_settings = var.auth_settings != null ? {
    "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET" = var.auth_settings_client_secret
  } : {}

  azure_web_jobs_storage_identity_app_settings = merge(
    {
      "AzureWebJobsStorage__credential"      = "managedidentity"
      "AzureWebJobsStorage__blobServiceUri"  = local.storage_primary_endpoints.blob
      "AzureWebJobsStorage__queueServiceUri" = local.storage_primary_endpoints.queue
      "AzureWebJobsStorage__tableServiceUri" = local.storage_primary_endpoints.table
    },
    local.storage_uses_user_assigned_identity ? {
      "AzureWebJobsStorage__clientId" = local.storage_managed_identity_client_id
    } : {},
  )

  function_app_settings = merge(
    var.additional_app_settings,
    local.azure_web_jobs_storage_identity_app_settings,
    local.acmebot_app_settings,
    local.auth_app_settings,
  )

  auth_settings_v2 = var.auth_settings != null ? {
    auth_enabled                  = var.auth_settings.enabled
    require_authentication        = var.auth_settings.enabled
    redirect_to_provider          = "azureactivedirectory"
    unauthenticated_client_action = "RedirectToLoginPage"
    identity_providers = {
      azure_active_directory = {
        enabled = true
        registration = {
          client_id                  = var.auth_settings.active_directory.client_id
          client_secret_setting_name = "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"
          open_id_issuer             = var.auth_settings.active_directory.tenant_auth_endpoint
        }
      }
    }
    login = {
      token_store = {
        enabled = false
      }
    }
  } : null

  storage_account_sku_name = "Standard_${var.storage_account.account_replication_type}"

  storage_role_definition_ids = {
    storage_blob_data_owner        = "${local.subscription_resource_id}/providers/Microsoft.Authorization/roleDefinitions/b7e6dc6d-f1e8-4753-8033-0f276bb0955b"
    storage_queue_data_contributor = "${local.subscription_resource_id}/providers/Microsoft.Authorization/roleDefinitions/974c5e8b-45b9-4653-ba55-5f855dd0fb88"
    storage_table_data_contributor = "${local.subscription_resource_id}/providers/Microsoft.Authorization/roleDefinitions/0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3"
  }
}
