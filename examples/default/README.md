# Default Example

This example deploys a minimal, publicly reachable Acmebot instance on Azure
Functions Flex Consumption. It is intended as a quickstart for evaluating the
module and understanding the required Acmebot settings.

It creates:

- A resource group for the example deployment.
- A Key Vault target for issued certificates.
- A Function App with a system-assigned managed identity.
- Identity-based Storage access for `AzureWebJobsStorage`.
- Azure DNS as the ACME DNS-01 challenge provider.

This example does not configure App Service Authentication. The root module
defaults to a private posture, so this example explicitly enables public network
access and permissive IP restriction defaults for a low-friction deployment. For
a private deployment, use the [`complete`](../complete) example.

## Deploy

Before applying, replace `admin@example.com` in [main.tf](main.tf) with the email
address used for the ACME account.

```bash
terraform init
terraform apply
```
