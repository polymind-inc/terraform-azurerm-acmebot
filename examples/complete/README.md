# Complete Example

Deploys Acmebot on Azure Functions Flex Consumption with a fully private,
enterprise-grade networking and identity posture. This example is self-contained:
it provisions the virtual network, subnets, and private DNS zones it needs, so it
can be applied against an empty subscription as-is.

It demonstrates:

- A self-contained virtual network with a Flex Consumption VNET integration subnet
  (delegated to `Microsoft.App/environments`) and a dedicated private endpoint subnet.
- Function App and Storage Account (`blob`, `queue`, `table`) Private Endpoints with
  private DNS zone groups, plus a Key Vault Private Endpoint managed by the example.
- Public network access disabled on the Function App, Storage Account, and Key Vault.
- A user-assigned managed identity used for both the Acmebot workload (Key Vault and
  Azure DNS access) and `AzureWebJobsStorage`, with the system-assigned identity disabled.
- App Service Authentication backed by a Microsoft Entra application.
- Zone-redundant (`ZRS`) Storage, a 90-day Log Analytics retention, and a
  `CanNotDelete` resource lock on the Function App.

Before applying, replace `admin@example.com` in [main.tf](main.tf) with the email
address used for the ACME account.

```bash
terraform init
terraform apply
```

## Notes

- The VNET integration subnet must be delegated to `Microsoft.App/environments`, be at
  least `/27`, and cannot host private endpoints, so a separate subnet is used for them.
  Ensure the `Microsoft.App` resource provider is registered in the subscription.
- Key Vault, Storage, and the Function App are reachable only over their private
  endpoints. Apply from a host with line of sight to the virtual network (for example,
  a peered network or a self-hosted agent) if you need to reach them afterwards.
  Terraform itself only performs control-plane operations here, so it does not require
  private data-plane access during `apply`.
- The `CanNotDelete` lock on the Function App is removed automatically by the module on
  `terraform destroy`.
