
locals {
  function_app_name = "func-${var.app_base_name}"

  acmebot_release_version = replace(var.acmebot_version, "/^v/", "")
  acmebot_major_version   = "v${split(".", local.acmebot_release_version)[0]}"
  acmebot_package_name    = var.acmebot_version == local.acmebot_major_version ? "latest" : local.acmebot_release_version
  acmebot_package_uri     = "https://stacmebotprod.blob.core.windows.net/acmebot/${local.acmebot_major_version}/${local.acmebot_package_name}.zip"

  storage_account_name = coalesce(
    var.storage_account_name,
    format(
      "st%s%s",
      substr(replace(lower(var.app_base_name), "/[^a-z0-9]/", ""), 0, 16),
      substr(md5("${data.azurerm_client_config.current.subscription_id}/${var.resource_group_name}/${var.app_base_name}"), 0, 6),
    )
  )

  deployment_container_name = format(
    "app-package-%s-%s",
    trim(substr(replace(replace(lower(local.function_app_name), "/[^a-z0-9-]/", ""), "/-+/", "-"), 0, 43), "-"),
    random_string.deployment_container_suffix.result,
  )

  external_account_binding = var.external_account_binding != null ? {
    "Acmebot__ExternalAccountBinding__KeyId"     = var.external_account_binding.key_id
    "Acmebot__ExternalAccountBinding__HmacKey"   = var.external_account_binding.hmac_key
    "Acmebot__ExternalAccountBinding__Algorithm" = var.external_account_binding.algorithm
  } : {}

  azure_dns = var.azure_dns != null ? {
    "Acmebot__AzureDns__SubscriptionId" = var.azure_dns.subscription_id
  } : {}

  azure_private_dns = var.azure_private_dns != null ? {
    "Acmebot__AzurePrivateDns__SubscriptionId" = var.azure_private_dns.subscription_id
  } : {}

  cloudflare = var.cloudflare != null ? {
    "Acmebot__Cloudflare__ApiToken" = var.cloudflare.api_token
  } : {}

  custom_dns = var.custom_dns != null ? {
    "Acmebot__CustomDns__Endpoint"           = var.custom_dns.endpoint
    "Acmebot__CustomDns__ApiKey"             = var.custom_dns.api_key
    "Acmebot__CustomDns__ApiKeyHeaderName"   = var.custom_dns.api_key_header_name
    "Acmebot__CustomDns__PropagationSeconds" = var.custom_dns.propagation_seconds
  } : {}

  dns_made_easy = var.dns_made_easy != null ? {
    "Acmebot__DnsMadeEasy__ApiKey"    = var.dns_made_easy.api_key
    "Acmebot__DnsMadeEasy__SecretKey" = var.dns_made_easy.secret_key
  } : {}

  gandi = var.gandi != null ? {
    "Acmebot__Gandi__ApiKey" = var.gandi.api_key
  } : {}

  go_daddy = var.go_daddy != null ? {
    "Acmebot__GoDaddy__ApiKey"    = var.go_daddy.api_key
    "Acmebot__GoDaddy__ApiSecret" = var.go_daddy.api_secret
  } : {}

  google_dns = var.google_dns != null ? {
    "Acmebot__GoogleDns__KeyFile64" = var.google_dns.key_file64
  } : {}

  route_53 = var.route_53 != null ? {
    "Acmebot__Route53__AccessKey" = var.route_53.access_key
    "Acmebot__Route53__SecretKey" = var.route_53.secret_key
    "Acmebot__Route53__Region"    = var.route_53.region
  } : {}

  trans_ip = var.trans_ip != null ? {
    "Acmebot__TransIp__CustomerName"   = var.trans_ip.customer_name
    "Acmebot__TransIp__PrivateKeyName" = var.trans_ip.private_key_name
  } : {}

  webhook_url = var.webhook_url != null ? {
    "Acmebot__Webhook" = var.webhook_url
  } : {}

  common = {
    "Acmebot__Contacts"           = var.mail_address
    "Acmebot__Endpoint"           = var.acme_endpoint
    "Acmebot__VaultBaseUrl"       = var.vault_uri
    "Acmebot__Environment"        = var.environment
    "Acmebot__MitigateChainOrder" = var.mitigate_chain_order
    "Acmebot__AppRoleRequired"    = var.app_role_required
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
  )

  auth_app_settings = var.auth_settings != null ? {
    "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET" = var.auth_settings.active_directory.client_secret
  } : {}
}
