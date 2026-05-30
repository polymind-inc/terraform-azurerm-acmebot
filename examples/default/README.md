# Default Example

Deploys Acmebot on Azure Functions Flex Consumption with:

- A system-assigned managed identity for the Function App and Storage access.
- Azure DNS as the ACME challenge provider.
- A Key Vault target for issued certificates.

This example explicitly keeps the quickstart publicly reachable with minimal networking and does not configure App Service Authentication. The module defaults to a private posture, so public network access and permissive IP restriction defaults are set here for a low-friction sample. For private deployments, remove those public overrides and configure VNET integration plus Function App and Storage Account Private Endpoints.

Before applying, replace `admin@example.com` in [main.tf](main.tf) with the email address used for the ACME account.

```bash
terraform init
terraform apply
```

For a private, enterprise-grade deployment with VNET integration, Function App and Storage Account Private Endpoints, private DNS, a user-assigned managed identity, and a resource lock, see the [`complete`](../complete) example.
