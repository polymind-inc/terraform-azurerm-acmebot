terraform {
  required_providers {
    azapi  = { source = "Azure/azapi" }
    modtm  = { source = "Azure/modtm" }
    random = { source = "hashicorp/random" }
  }
}

# output is unknown during plan, as with a newly created application password.
resource "terraform_data" "client_secret" {
  input = "test-secret"
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

  auth_settings = {
    enabled          = true
    default_provider = "keycloak"
    microsoft_entra = {
      client_id            = "00000000-0000-0000-0000-000000000000"
      client_secret        = sensitive(terraform_data.client_secret.output)
      tenant_auth_endpoint = "https://login.microsoftonline.com/00000000-0000-0000-0000-000000000000/v2.0"
    }
    custom_open_id_connect_providers = {
      keycloak = {
        client_id                        = "acmebot"
        client_secret                    = sensitive(terraform_data.client_secret.output)
        well_known_open_id_configuration = "https://sso.example.com/realms/example/.well-known/openid-configuration"
      }
    }
  }
}
