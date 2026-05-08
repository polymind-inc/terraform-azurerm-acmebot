# Acmebot Terraform module

[![Validate](https://github.com/polymind-inc/terraform-azurerm-acmebot/actions/workflows/validate.yml/badge.svg)](https://github.com/polymind-inc/terraform-azurerm-acmebot/actions/workflows/validate.yml)
[![Release](https://badgen.net/github/release/polymind-inc/terraform-azurerm-acmebot)](https://github.com/polymind-inc/terraform-azurerm-acmebot/releases/latest)
[![License](https://badgen.net/github/license/polymind-inc/terraform-azurerm-acmebot)](https://github.com/polymind-inc/terraform-azurerm-acmebot/blob/master/LICENSE)
[![Terraform Registry](https://badgen.net/badge/terraform/registry/5c4ee5)](https://registry.terraform.io/modules/polymind-inc/acmebot/azurerm/latest)

## Usage

```hcl
module "acmebot" {
  source  = "polymind-inc/acmebot/azurerm"
  version = "~> 1.0"

  app_base_name         = "acmebot-module"
  resource_group_name   = azurerm_resource_group.default.name
  location              = azurerm_resource_group.default.location
  mail_address          = "YOUR-EMAIL-ADDRESS"
  vault_uri             = azurerm_key_vault.default.vault_uri
  acmebot_version       = "v5"

  azure_dns = {
    subscription_id = data.azurerm_client_config.current.subscription_id
  }

  maximum_instance_count = 50
  instance_memory_in_mb  = 2048
}
```

## Requirements

- Terraform `>= 1.3.0` with the `hashicorp/azurerm` provider `~> 4.0`

## Notes

- Secret inputs are marked as sensitive, but they are still stored in Terraform state when used to configure the Function App.
- Flex Consumption does not support `:` in app setting keys, so the module uses `Acmebot__...` keys for nested configuration.
- `additional_app_settings` cannot override reserved `Acmebot__*` settings or `MICROSOFT_PROVIDER_AUTHENTICATION_SECRET`.
- Set `acmebot_version` to a major version such as `v5` to deploy `v5/latest.zip`, or to a specific version such as `v5.0.1` to deploy `v5/5.0.1.zip`.
- By default the module generates a deterministic storage account name with a hash suffix. To preserve an existing name during upgrades, set `storage_account_name` explicitly.
- The `api_key` output is disabled by default. Set `export_api_key = true` only when you need Terraform to read and expose the default host key.
- You can tune Flex Consumption behavior with `maximum_instance_count`, `instance_memory_in_mb`, and `public_network_access_enabled`.

## License

This project is licensed under the [Apache License 2.0](https://github.com/polymind-inc/terraform-azurerm-acmebot/blob/master/LICENSE)
