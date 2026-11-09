terraform {
  required_providers {
    azapi  = { source = "Azure/azapi" }
    modtm  = { source = "Azure/modtm" }
    random = { source = "hashicorp/random" }
  }
}

# output is unknown during plan, as with a newly created user-assigned identity.
resource "terraform_data" "identity_client_id" {
  input = "11111111-1111-1111-1111-111111111111"
}

module "under_test" {
  source = "../../.."

  name                          = "func-acmebot-test"
  parent_id                     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-acmebot-test"
  location                      = "eastus"
  public_network_access_enabled = true
  storage_account = {
    public_network_access_enabled = true
  }

  acmebot = {
    version      = "5.0.1"
    mail_address = "test@example.com"
    vault_uri    = "https://kv-acmebot-test.vault.azure.net/"
    dns_providers = {
      azure_dns = { subscription_id = "00000000-0000-0000-0000-000000000000" }
    }
  }

  managed_identities = {
    user_assigned_resource_ids = [
      "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-acmebot-test/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-easy-auth"
    ]
  }

  auth_settings = {
    enabled = true
    microsoft_entra = {
      client_id                  = "00000000-0000-0000-0000-000000000000"
      managed_identity_client_id = sensitive(terraform_data.identity_client_id.output)
      tenant_auth_endpoint       = "https://login.microsoftonline.com/00000000-0000-0000-0000-000000000000/v2.0"
    }
  }
}
