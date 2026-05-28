# Default Example

Deploys Acmebot on Azure Functions Flex Consumption with:

- A system-assigned managed identity for the Function App and Storage access.
- App Service Authentication backed by a Microsoft Entra application.
- Azure DNS as the ACME challenge provider.
- A Key Vault target for issued certificates.

This example explicitly keeps the quickstart publicly reachable with minimal networking. The module defaults to a private posture, so public network access and permissive IP restriction defaults are set here for a low-friction sample. For private deployments, remove those public overrides and configure VNET integration plus Function App and Storage Account Private Endpoints.

Before applying, replace `admin@example.com` in [main.tf](main.tf) with the email address used for the ACME account.

```bash
terraform init
terraform apply
```

The commented sections in [main.tf](main.tf) show the additional inputs commonly needed for private networking and user-assigned managed identities.
