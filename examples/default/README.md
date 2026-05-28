# Default Example

Deploys Acmebot on Azure Functions Flex Consumption with a system-assigned managed identity, App Service Authentication backed by a Microsoft Entra application, and Azure DNS as the ACME challenge provider.

This example explicitly disables the module's enterprise-level defaults so the quickstart remains publicly reachable with minimal networking. For production and enterprise deployments, keep `enterprise_level_defaults_enabled` at its default value and configure VNET integration plus Function App and Storage Account Private Endpoints.

```bash
terraform init
terraform apply
```

Replace `YOUR-EMAIL-ADDRESS` in `main.tf` with the email address used for the ACME account before applying.
