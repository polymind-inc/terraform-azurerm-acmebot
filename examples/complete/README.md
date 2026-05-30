# Complete Example

This example deploys Acmebot with private networking, App Service Authentication,
and a user-assigned managed identity. It creates its own resource group, virtual
network, subnets, private DNS zones, and private endpoints.

It demonstrates:

- A dedicated virtual network with a Flex Consumption VNET integration subnet
  delegated to `Microsoft.App/environments`.
- A separate private endpoint subnet for Key Vault, Storage, and the Function
  App.
- Private DNS zone groups for the Function App and Storage Account private
  endpoints.
- Public network access disabled on the Function App, Storage Account, and Key
  Vault.
- A user-assigned managed identity used by both Acmebot and `AzureWebJobsStorage`.
- App Service Authentication backed by a Microsoft Entra application.
- Zone-redundant Storage, 90-day Log Analytics retention, and a `CanNotDelete`
  lock on the Function App.

## Deploy

Before applying, replace `admin@example.com` in [main.tf](main.tf) with the email
address used for the ACME account.

```bash
terraform init
terraform apply
```

## Notes

- The VNET integration subnet must be at least `/27`, delegated to
  `Microsoft.App/environments`, and separate from the private endpoint subnet.
- Ensure the `Microsoft.App` resource provider is registered in the subscription.
- Key Vault, Storage, and the Function App are reachable only through private
  endpoints after deployment.
- Terraform performs only control-plane operations during `apply`, so the machine
  running Terraform does not need private data-plane access to the VNET.
- The `CanNotDelete` lock on the Function App is removed automatically by the
  module during `terraform destroy`.
