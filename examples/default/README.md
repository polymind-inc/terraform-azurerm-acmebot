# Default Example

Deploys Acmebot on Azure Functions Flex Consumption with a system-assigned managed identity, App Service Authentication backed by a Microsoft Entra application, and Azure DNS as the ACME challenge provider. Optional VNET integration, Private Endpoints, and IP restrictions are shown as commented blocks.

```bash
terraform init
terraform apply
```

Replace `YOUR-EMAIL-ADDRESS` in `main.tf` with the email address used for the ACME account before applying.
