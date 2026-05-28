# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this module, please report it privately via [GitHub Security Advisories](https://github.com/polymind-inc/terraform-azurerm-acmebot/security/advisories/new). Do not open a public issue for security reports.

Please include:

- A description of the issue and its potential impact.
- Steps to reproduce, or a proof-of-concept configuration if possible.
- The module version and Terraform version where the issue was observed.

## Sensitive Inputs

This module accepts secrets through several inputs, including but not limited to:

- `auth_settings.active_directory.client_secret`
- `acmebot.dns_providers.*` credentials
- `acmebot.external_account_binding.hmac_key`
- `additional_app_settings` values

These secrets are passed to the Function App as application settings and are therefore **persisted in Terraform state**. Use a remote backend with state encryption and access control, and avoid checking state files into source control.
