locals {
  function_app_name = var.name
  tags              = var.tags

  resource_group_id = "/subscriptions/${data.azapi_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"

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

  gandi = var.acmebot.dns_providers.gandi != null ? {
    "Acmebot__Gandi__ApiKey" = var.acmebot.dns_providers.gandi.api_key
  } : {}

  go_daddy = var.acmebot.dns_providers.go_daddy != null ? {
    "Acmebot__GoDaddy__ApiKey"    = var.acmebot.dns_providers.go_daddy.api_key
    "Acmebot__GoDaddy__ApiSecret" = var.acmebot.dns_providers.go_daddy.api_secret
  } : {}

  google_dns = var.acmebot.dns_providers.google_dns != null ? {
    "Acmebot__GoogleDns__KeyFile64" = var.acmebot.dns_providers.google_dns.key_file64
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

  webhook_url = var.acmebot.webhook_url != null ? {
    "Acmebot__Webhook" = var.acmebot.webhook_url
  } : {}

  acmebot_managed_identity = var.acmebot.managed_identity_client_id != null ? {
    "Acmebot__ManagedIdentityClientId" = var.acmebot.managed_identity_client_id
  } : {}

  common = {
    "Acmebot__Contacts"           = var.acmebot.mail_address
    "Acmebot__Endpoint"           = var.acmebot.acme_endpoint
    "Acmebot__VaultBaseUrl"       = var.acmebot.vault_uri
    "Acmebot__Environment"        = var.acmebot.environment
    "Acmebot__MitigateChainOrder" = tostring(var.acmebot.mitigate_chain_order)
    "Acmebot__AppRoleRequired"    = tostring(var.acmebot.app_role_required)
  }

  acmebot_app_settings = merge(
    local.common,
    local.external_account_binding,
    local.azure_dns,
    local.azure_private_dns,
    local.cloudflare,
    local.custom_dns,
    local.dns_made_easy,
    local.gandi,
    local.go_daddy,
    local.google_dns,
    local.route_53,
    local.trans_ip,
    local.webhook_url,
    local.acmebot_managed_identity,
  )

  auth_app_settings = var.auth_settings != null ? {
    "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET" = var.auth_settings_client_secret
  } : {}

  function_app_settings = merge(
    var.additional_app_settings,
    local.acmebot_app_settings,
    local.auth_app_settings,
  )

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

  storage_account_role_assignments = {
    function_app_blob_data_owner = {
      role_definition_id_or_name = "Storage Blob Data Owner"
      principal_id               = module.this.system_assigned_mi_principal_id
      principal_type             = "ServicePrincipal"
    }
  }
}
