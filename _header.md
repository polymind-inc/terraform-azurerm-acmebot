# Azure Acmebot Terraform Module

Deploy Azure Acmebot on Azure Functions Flex Consumption with managed identity
storage access, optional private networking, optional App Service Authentication,
and managed observability resources.

This module uses an AzAPI-first implementation with Azure Verified Module
(AVM)-aligned interface patterns. It is published in the Terraform Registry under
the `azurerm` namespace, but it is not an official Azure Verified Module.

## Usage

Use the module from the Terraform Registry. The following example shows the main
inputs for a private deployment; see the runnable examples for complete
configurations.

> [!IMPORTANT]
> Azure Functions Flex Consumption currently returns a corrupted OneDeploy ARM
> response, so `terraform apply` can fail on the package deployment step even
> when the package is deployed successfully. Until the platform issue is
> resolved, set `skip_package_deployment = true` and deploy the package
> out-of-band as described in [Operations](#operations).

```hcl
module "acmebot" {
  source  = "polymind-inc/acmebot/azurerm"
  version = "~> 1.0"

  name      = "func-acmebot-module"
  parent_id = azurerm_resource_group.default.id
  location  = azurerm_resource_group.default.location
  tags = {
    workload = "acmebot"
  }

  acmebot = {
    version      = "5.0.1"
    mail_address = "admin@example.com"
    vault_uri    = azurerm_key_vault.default.vault_uri

    dns_providers = {
      azure_dns = {
        subscription_id = data.azurerm_client_config.current.subscription_id
      }
    }
  }

  storage_account = {
    account_replication_type      = "ZRS"
    public_network_access_enabled = false

    private_endpoints = {
      blob = {
        subnet_resource_id = azurerm_subnet.private_endpoints.id
        subresource_name   = "blob"
        private_dns_zone_resource_ids = [
          azurerm_private_dns_zone.storage["blob"].id
        ]
      }
      queue = {
        subnet_resource_id = azurerm_subnet.private_endpoints.id
        subresource_name   = "queue"
        private_dns_zone_resource_ids = [
          azurerm_private_dns_zone.storage["queue"].id
        ]
      }
      table = {
        subnet_resource_id = azurerm_subnet.private_endpoints.id
        subresource_name   = "table"
        private_dns_zone_resource_ids = [
          azurerm_private_dns_zone.storage["table"].id
        ]
      }
    }
  }

  private_endpoints = {
    sites = {
      subnet_resource_id = azurerm_subnet.private_endpoints.id
      private_dns_zone_resource_ids = [
        azurerm_private_dns_zone.sites.id
      ]
    }
  }

  virtual_network_subnet_id = azurerm_subnet.functions.id

  managed_identities = {
    system_assigned = true
  }

  site_config = {
    vnet_route_all_enabled            = true
    ip_restriction_default_action     = "Deny"
    scm_ip_restriction_default_action = "Deny"
    scm_use_main_ip_restriction       = true
  }

  log_analytics_workspace = {
    retention_in_days = 90
  }

  lock = {
    kind = "CanNotDelete"
  }
}
```

## Examples

Runnable examples are available under [`examples`](examples):

- [`default`](examples/default) - A public quickstart with minimal networking, a system-assigned managed identity, a Key Vault target, and Azure DNS.
- [`complete`](examples/complete) - A fully private deployment with VNET integration, Function App and Storage Account Private Endpoints, private DNS, a user-assigned managed identity, and a resource lock.

## Authentication

Omit `auth_settings` to leave App Service Authentication unconfigured. To
explicitly disable it, set `auth_settings = { enabled = false }`; no provider
credentials are required in that case.

The [`complete`](examples/complete) example configures Microsoft Entra ID. For a
custom OIDC provider such as Keycloak, use:

```hcl
auth_settings = {
  enabled          = true
  default_provider = "keycloak"

  custom_open_id_connect_providers = {
    keycloak = {
      client_id                        = var.keycloak_client_id
      client_secret                    = var.keycloak_client_secret
      well_known_open_id_configuration = "https://sso.example.com/realms/example/.well-known/openid-configuration"
    }
  }
}
```

Entra and custom OIDC providers can be configured together. `default_provider`
selects the login redirect: `microsoft_entra` (the default) selects Entra, and a
custom provider's map key selects that provider. The selected provider must be
configured when authentication is enabled. Custom provider names must be non-empty
and contain only ASCII letters, digits, periods (`.`), and underscores (`_`), so
they can also be used in the generated App Service setting names. Azure does not
support hyphens in [custom OIDC provider names](https://learn.microsoft.com/azure/app-service/configure-authentication-provider-openid-connect).
`microsoft_entra` and `azureactivedirectory` are reserved (case-insensitive) and
cannot be custom provider names. Every configured provider requires its client
ID, secret, and issuer/discovery URL, including when authentication is disabled.

The module generates `MICROSOFT_PROVIDER_AUTHENTICATION_SECRET` for Entra and
`CUSTOM_OIDC_<provider-name>_AUTHENTICATION_SECRET` for each custom provider and
wires their references internally. Credentials remain sensitive in app settings
and Terraform state. Only provider names, client IDs, endpoints, and other
non-secret authentication metadata are declassified for AVM's `for_each` use.

### Migrating Existing Authentication Settings

This is a breaking input change. Rename `auth_settings.active_directory` to
`auth_settings.microsoft_entra`, move the former `auth_settings_client_secret`
value into that object's `client_secret`, and remove the old top-level input:

```hcl
auth_settings = {
  enabled = true
  microsoft_entra = {
    client_id            = var.client_id
    client_secret        = var.client_secret
    tenant_auth_endpoint = var.tenant_auth_endpoint
  }
}
```

Existing Entra configurations can omit `default_provider`; the module translates
its default `microsoft_entra` to Azure's `azureactivedirectory` internally.

Terraform 1.12 or later is now required. The existing module and current AVM
dependencies rely on null-safe logical evaluation and write-only attributes
that are unavailable with the former Terraform 1.10 minimum.

## Design Notes

### Core Inputs

- `name` is the Function App name. It must be 2-32 characters, contain only
  letters, numbers, and hyphens, and start and end with a letter or number.
- `parent_id` is the AVM-aligned deployment scope input and must be the resource
  ID of an existing resource group.
- `acmebot.version` must target a published Acmebot v5 or later package. The
  validation checks the version format, but an unpublished package version fails
  during deployment.
- Acmebot workload settings are grouped under `acmebot`, including ACME account
  settings, Key Vault target, DNS provider configuration, webhook configuration,
  and External Account Binding.

### Security and Identity

- Secret inputs are marked as sensitive, but they are still stored in Terraform
  state when used to configure the Function App.
- `AzureWebJobsStorage` and Flex Consumption deployment storage use managed
  identity. By default, the module uses the Function App system-assigned identity.
- The selected Storage identity receives Storage Blob Data Owner, Storage Queue
  Data Contributor, and Storage Table Data Contributor on the module-created
  Storage Account.
- To make Acmebot use a user-assigned identity, attach it through
  `managed_identities.user_assigned_resource_ids` and set
  `acmebot.managed_identity_client_id`.
- The module does not grant Acmebot access to Key Vault or DNS. Assign the
  Acmebot identity Key Vault Certificates Officer on the target Key Vault, and
  DNS Zone Contributor (for `azure_dns`) or Private DNS Zone Contributor (for
  `azure_private_dns`) on the zones or their resource group.
- Storage Account shared key authorization is disabled by default. Blob versioning,
  change feed, soft delete, Entra-first portal auth, and infrastructure encryption
  are enabled by default.

### Networking

- The module is private by default: Function App and Storage Account public
  network access default to disabled.
- Quickstart examples explicitly enable public access and do not configure App
  Service Authentication. Use them for evaluation, not as a locked-down
  production baseline.
- When `virtual_network_subnet_id` is set, configure Storage private endpoints so
  the Function App can reach its Storage Account through Private Endpoint.
- When Storage public access is disabled, configure `blob`, `queue`, and `table`
  private endpoints.
- The Flex Consumption VNET integration subnet cannot host private endpoints, so
  use a separate subnet for private endpoints.
- `acmebot.use_system_name_server` controls whether Acmebot uses the platform DNS
  resolver instead of Google Public DNS for ACME challenge verification.

### Operations

- Azure Functions Flex Consumption currently returns a corrupted OneDeploy ARM
  response, causing `azapi_resource.deployment` to fail even when the package is
  deployed successfully. Set `skip_package_deployment = true` to omit OneDeploy
  from Terraform and deploy the package out-of-band. `export_api_key` must remain
  `false` in this mode because Terraform cannot order the host key lookup after
  an external deployment.
- The following command shows how to deploy the package after Terraform creates
  the Function App. Replace the placeholders with the module output and desired
  Acmebot version. The Azure CLI may still report the response parsing error;
  verify the resulting deployment separately until the Azure platform issue is
  resolved.

  ```bash
  az rest --method PUT \
    --url "https://management.azure.com<function-app-resource-id>/extensions/onedeploy?api-version=2025-03-01" \
    --body '{"properties":{"type":"zip","packageUri":"https://github.com/polymind-inc/acmebot/releases/download/v<version>/acmebot.zip","remoteBuild":false}}'
  ```

- Set `log_analytics_workspace.resource_id` and/or
  `application_insights.resource_id` to reuse existing monitoring resources.
- When `application_insights.resource_id` comes from a resource created in the
  same Terraform operation, set `application_insights.create = false` so the
  module can determine resource counts during planning.

  ```hcl
  application_insights = {
    create      = false
    resource_id = azapi_resource.application_insights.id
  }
  ```

- Child resources inherit `var.tags` by default and support child-specific tag
  overrides where Azure supports tags.
- Child resource settings can be overridden with `storage_account`,
  `deployment_container`, `service_plan`, `log_analytics_workspace`, and
  `application_insights`.
- AVM-style `lock`, `managed_identities`, `role_assignments`, and
  `private_endpoints` inputs can apply resource locks, managed identities, RBAC
  assignments, and Private Endpoints to the Function App.

### Compliance Considerations

This module can support technical controls for information security frameworks
such as ISO/IEC 27001, but it does not provide or guarantee certification by
itself. ISO/IEC 27001 certification depends on the consumer's ISMS scope, risk
assessment, operating procedures, evidence collection, and independent audit.

Microsoft Azure services undergo independent third-party audits for ISO/IEC
27001. See the
[Azure ISO/IEC 27001 compliance documentation](https://learn.microsoft.com/azure/compliance/offerings/offering-iso-27001)
for current Microsoft audit scope, reports, and customer responsibility
guidance.

For a security-focused deployment baseline, start from the
[`complete`](examples/complete) example and keep the following controls enabled
or implemented in the surrounding platform:

- Disable public network access for the Function App, Storage Account, and Key
  Vault; use Private Endpoints and private DNS for data-plane access.
- Use managed identities and RBAC for Azure resource access; avoid long-lived
  secrets where the upstream Acmebot provider supports identity-based access.
- Enable App Service Authentication and require the appropriate Microsoft Entra
  users, groups, or app roles for administrative access.
- Send application, platform, and resource diagnostic logs to Log Analytics or a
  central SIEM with retention aligned to the organization's audit policy.
- Protect Terraform state with encryption, least-privilege access, versioning,
  and operational controls because sensitive application settings are stored in
  state.
- Apply organization-level guardrails such as Azure Policy regulatory
  compliance initiatives, Microsoft Defender for Cloud, privileged access
  management, periodic access reviews, incident response procedures, and backup
  or recovery testing.
