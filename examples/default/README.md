# Default Example

Deploys Acmebot on Azure Functions Flex Consumption with:

- A system-assigned managed identity for the Function App and Storage access.
- App Service Authentication backed by a Microsoft Entra application.
- Azure DNS as the ACME challenge provider.
- A Key Vault target for issued certificates.

This example disables `enterprise_level_defaults_enabled` so the quickstart remains publicly reachable with minimal networking. For production or enterprise deployments, keep the module default and configure VNET integration plus Function App and Storage Account Private Endpoints.

Before applying, replace `YOUR-EMAIL-ADDRESS` in [main.tf](main.tf) with the email address used for the ACME account.

```bash
terraform init
terraform apply
```

The commented sections in [main.tf](main.tf) show the additional inputs commonly needed for private networking and user-assigned managed identities.
