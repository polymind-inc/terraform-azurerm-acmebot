locals {
  function_app_name = var.name
  tags              = var.tags

  resource_group_id        = "/subscriptions/${data.azapi_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  subscription_resource_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}"

  storage_uses_user_assigned_identity = var.storage_managed_identity.user_assigned_resource_id != null
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
      substr(md5("${data.azapi_client_config.current.subscription_id}/${var.resource_group_name}/${var.name}"), 0, 6),
    )
  )

  deployment_container_name = coalesce(
    var.deployment_container.name,
    format(
      "app-package-%s-%s",
      trim(substr(replace(replace(lower(local.function_app_name), "/[^a-z0-9-]/", ""), "/-+/", "-"), 0, 43), "-"),
      random_string.deployment_container_suffix.result,
    )
  )

  storage_container_endpoint_url = "https://${local.storage_account_name}.blob.core.windows.net/${local.deployment_container_name}"

  acmebot_major_version = "v${split(".", var.acmebot.version)[0]}"
  acmebot_package_uri   = "https://stacmebotprod.blob.core.windows.net/acmebot/${local.acmebot_major_version}/${var.acmebot.version}.zip"

  external_account_binding = var.acmebot.external_account_binding != null ? {
    "Acmebot__ExternalAccountBinding__KeyId"     = var.acmebot.external_account_binding.key_id
    "Acmebot__ExternalAccountBinding__HmacKey"   = var.acmebot.external_account_binding.hmac_key
    "Acmebot__ExternalAccountBinding__Algorithm" = var.acmebot.external_account_binding.algorithm
  } : {}

  akamai = var.acmebot.dns_providers.akamai != null ? {
    "Acmebot__Akamai__Host"         = var.acmebot.dns_providers.akamai.host
    "Acmebot__Akamai__ClientToken"  = var.acmebot.dns_providers.akamai.client_token
    "Acmebot__Akamai__ClientSecret" = var.acmebot.dns_providers.akamai.client_secret
    "Acmebot__Akamai__AccessToken"  = var.acmebot.dns_providers.akamai.access_token
  } : {}

  azure_dns = var.acmebot.dns_providers.azure_dns != null ? {
    "Acmebot__AzureDns__SubscriptionId" = var.acmebot.dns_providers.azure_dns.subscription_id
  } : {}

  azure_private_dns = var.acmebot.dns_providers.azure_private_dns != null ? {
    "Acmebot__AzurePrivateDns__SubscriptionId" = var.acmebot.dns_providers.azure_private_dns.subscription_id
  } : {}

  cloudflare = var.acmebot.dns_providers.cloudflare != null ? {
    "Acmebot__Cloudflare__ApiToken" = var.acmebot.dns_providers.cloudflare.api_token
  } : {}

  custom_dns = var.acmebot.dns_providers.custom_dns != null ? {
    "Acmebot__CustomDns__Endpoint"           = var.acmebot.dns_providers.custom_dns.endpoint
    "Acmebot__CustomDns__ApiKey"             = var.acmebot.dns_providers.custom_dns.api_key
    "Acmebot__CustomDns__ApiKeyHeaderName"   = var.acmebot.dns_providers.custom_dns.api_key_header_name
    "Acmebot__CustomDns__PropagationSeconds" = var.acmebot.dns_providers.custom_dns.propagation_seconds
  } : {}

  dns_made_easy = var.acmebot.dns_providers.dns_made_easy != null ? {
    "Acmebot__DnsMadeEasy__ApiKey"    = var.acmebot.dns_providers.dns_made_easy.api_key
    "Acmebot__DnsMadeEasy__SecretKey" = var.acmebot.dns_providers.dns_made_easy.secret_key
  } : {}

  gandi_live_dns_options = var.acmebot.dns_providers.gandi_live_dns != null ? var.acmebot.dns_providers.gandi_live_dns : var.acmebot.dns_providers.gandi

  gandi_live_dns = local.gandi_live_dns_options != null ? {
    "Acmebot__GandiLiveDns__ApiKey" = local.gandi_live_dns_options.api_key
  } : {}

  go_daddy = var.acmebot.dns_providers.go_daddy != null ? {
    "Acmebot__GoDaddy__ApiKey"    = var.acmebot.dns_providers.go_daddy.api_key
    "Acmebot__GoDaddy__ApiSecret" = var.acmebot.dns_providers.go_daddy.api_secret
  } : {}

  google_dns = var.acmebot.dns_providers.google_dns != null ? {
    "Acmebot__GoogleDns__KeyFile64" = var.acmebot.dns_providers.google_dns.key_file64
  } : {}

  ionos_dns = var.acmebot.dns_providers.ionos_dns != null ? {
    "Acmebot__IonosDns__ApiKey" = var.acmebot.dns_providers.ionos_dns.api_key
  } : {}

  ovh = var.acmebot.dns_providers.ovh != null ? {
    "Acmebot__Ovh__Endpoint"          = var.acmebot.dns_providers.ovh.endpoint
    "Acmebot__Ovh__ApplicationKey"    = var.acmebot.dns_providers.ovh.application_key
    "Acmebot__Ovh__ApplicationSecret" = var.acmebot.dns_providers.ovh.application_secret
    "Acmebot__Ovh__ConsumerKey"       = var.acmebot.dns_providers.ovh.consumer_key
  } : {}

  power_dns = var.acmebot.dns_providers.power_dns != null ? {
    "Acmebot__PowerDns__Endpoint" = var.acmebot.dns_providers.power_dns.endpoint
    "Acmebot__PowerDns__ApiKey"   = var.acmebot.dns_providers.power_dns.api_key
    "Acmebot__PowerDns__ServerId" = var.acmebot.dns_providers.power_dns.server_id
  } : {}

  regfish = var.acmebot.dns_providers.regfish != null ? {
    "Acmebot__Regfish__ApiKey" = var.acmebot.dns_providers.regfish.api_key
  } : {}

  route_53 = var.acmebot.dns_providers.route_53 != null ? {
    "Acmebot__Route53__AccessKey" = var.acmebot.dns_providers.route_53.access_key
    "Acmebot__Route53__SecretKey" = var.acmebot.dns_providers.route_53.secret_key
    "Acmebot__Route53__Region"    = var.acmebot.dns_providers.route_53.region
  } : {}

  trans_ip = var.acmebot.dns_providers.trans_ip != null ? {
    "Acmebot__TransIp__CustomerName"   = var.acmebot.dns_providers.trans_ip.customer_name
    "Acmebot__TransIp__PrivateKeyName" = var.acmebot.dns_providers.trans_ip.private_key_name
  } : {}

  united_domains = var.acmebot.dns_providers.united_domains != null ? {
    "Acmebot__UnitedDomains__ApiKey" = var.acmebot.dns_providers.united_domains.api_key
  } : {}

  webhook_url = var.acmebot.webhook_url != null ? {
    "Acmebot__Webhook" = var.acmebot.webhook_url
  } : {}

  preferred_chain = var.acmebot.preferred_chain != null ? {
    "Acmebot__PreferredChain" = var.acmebot.preferred_chain
  } : {}

  preferred_profile = var.acmebot.preferred_profile != null ? {
    "Acmebot__PreferredProfile" = var.acmebot.preferred_profile
  } : {}

  acmebot_managed_identity = var.acmebot.managed_identity_client_id != null ? {
    "Acmebot__ManagedIdentityClientId" = var.acmebot.managed_identity_client_id
  } : {}

  common = {
    "Acmebot__Contacts"            = var.acmebot.mail_address
    "Acmebot__Endpoint"            = var.acmebot.acme_endpoint
    "Acmebot__VaultBaseUrl"        = var.acmebot.vault_uri
    "Acmebot__Environment"         = var.acmebot.environment
    "Acmebot__RenewBeforeExpiry"   = tostring(var.acmebot.renew_before_expiry)
    "Acmebot__UseSystemNameServer" = tostring(var.acmebot.use_system_name_server)
    "Acmebot:AppRoleRequired"      = tostring(var.acmebot.app_role_required)
  }

  acmebot_app_settings = merge(
    local.common,
    local.external_account_binding,
    local.akamai,
    local.azure_dns,
    local.azure_private_dns,
    local.cloudflare,
    local.custom_dns,
    local.dns_made_easy,
    local.gandi_live_dns,
    local.go_daddy,
    local.google_dns,
    local.ionos_dns,
    local.ovh,
    local.power_dns,
    local.regfish,
    local.route_53,
    local.trans_ip,
    local.united_domains,
    local.webhook_url,
    local.preferred_chain,
    local.preferred_profile,
    local.acmebot_managed_identity,
  )

  auth_app_settings = var.auth_settings != null ? {
    "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET" = var.auth_settings_client_secret
  } : {}

  azure_web_jobs_storage_user_assigned_identity_app_settings = local.storage_uses_user_assigned_identity ? {
    "AzureWebJobsStorage__credential" = "managedidentity"
    "AzureWebJobsStorage__clientId"   = local.storage_managed_identity_client_id
  } : {}

  function_app_settings = merge(
    var.additional_app_settings,
    local.azure_web_jobs_storage_user_assigned_identity_app_settings,
    local.acmebot_app_settings,
    local.auth_app_settings,
  )

  function_app_diagnostic_settings = var.managed_diagnostic_settings_enabled && length(var.diagnostic_settings) == 0 ? {
    default = {
      workspace_resource_id = azapi_resource.log_analytics_workspace.id
    }
  } : var.diagnostic_settings

  storage_account_diagnostic_settings = var.managed_diagnostic_settings_enabled ? {
    default = {
      workspace_resource_id = azapi_resource.log_analytics_workspace.id
      metrics = [
        {
          category = "Transaction"
        }
      ]
    }
  } : {}

  storage_service_diagnostic_settings = var.managed_diagnostic_settings_enabled ? {
    default = {
      workspace_resource_id = azapi_resource.log_analytics_workspace.id
      logs = [
        {
          category = "StorageRead"
        },
        {
          category = "StorageWrite"
        },
        {
          category = "StorageDelete"
        },
      ]
      metrics = [
        {
          category = "Transaction"
        }
      ]
    }
  } : {}

  auth_settings_v2 = var.auth_settings != null ? {
    auth_enabled                  = var.auth_settings.enabled
    require_authentication        = true
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
    storage_account_contributor    = "${local.subscription_resource_id}/providers/Microsoft.Authorization/roleDefinitions/17d1049b-9a84-46fb-8f53-869881c3d3ab"
    storage_blob_data_owner        = "${local.subscription_resource_id}/providers/Microsoft.Authorization/roleDefinitions/b7e6dc6d-f1e8-4753-8033-0f276bb0955b"
    storage_queue_data_contributor = "${local.subscription_resource_id}/providers/Microsoft.Authorization/roleDefinitions/974c5e8b-45b9-4653-ba55-5f855dd0fb88"
  }
}
