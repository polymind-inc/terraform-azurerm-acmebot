mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_id = "00000000-0000-0000-0000-000000000000"
      tenant_id       = "00000000-0000-0000-0000-000000000000"
      object_id       = "00000000-0000-0000-0000-000000000000"
      client_id       = "00000000-0000-0000-0000-000000000000"
    }
  }

  mock_data "azapi_resource_action" {
    defaults = {
      output = {
        functionKeys = {
          default = "test-function-key"
        }
      }
    }
  }

  mock_data "azapi_resource" {
    defaults = {
      output = {
        properties = {
          clientId            = "11111111-1111-1111-1111-111111111111"
          principalId         = "22222222-2222-2222-2222-222222222222"
          ConnectionString    = "InstrumentationKey=33333333-3333-3333-3333-333333333333;IngestionEndpoint=https://eastus-0.in.applicationinsights.azure.com/"
          WorkspaceResourceId = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-observability/providers/Microsoft.OperationalInsights/workspaces/log-existing"
          primaryEndpoints = {
            blob  = "https://stacmebottest.blob.core.windows.net/"
            queue = "https://stacmebottest.queue.core.windows.net/"
            table = "https://stacmebottest.table.core.windows.net/"
          }
        }
      }
    }
  }
}
mock_provider "random" {}
mock_provider "modtm" {}

variables {
  name      = "func-acmebot-test"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-acmebot-test"
  location  = "eastus"

  acmebot = {
    version      = "5.0.1"
    mail_address = "test@example.com"
    vault_uri    = "https://kv-acmebot-test.vault.azure.net/"

    dns_providers = {
      azure_dns = {
        subscription_id = "00000000-0000-0000-0000-000000000000"
      }
    }
  }

  managed_identities = {
    system_assigned = true
  }

  virtual_network_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-acmebot"

  storage_account = {
    private_endpoints = {
      blob = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-storage-private-endpoints"
        subresource_name   = "blob"
        private_dns_zone_resource_ids = [
          "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"
        ]
      }
      queue = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-storage-private-endpoints"
        subresource_name   = "queue"
        private_dns_zone_resource_ids = [
          "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/privateDnsZones/privatelink.queue.core.windows.net"
        ]
      }
      table = {
        subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-storage-private-endpoints"
        subresource_name   = "table"
        private_dns_zone_resource_ids = [
          "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/privateDnsZones/privatelink.table.core.windows.net"
        ]
      }
    }
  }

  private_endpoints = {
    primary = {
      subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-private-endpoints"
      private_dns_zone_resource_ids = [
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/privateDnsZones/privatelink.azurewebsites.net"
      ]
    }
  }
}

run "authentication_omitted" {
  command = plan

  assert {
    condition     = local.auth_settings_v2 == null && length(local.auth_app_settings) == 0
    error_message = "Omitting authentication must omit the auth resource and secret app settings."
  }
}

run "authentication_explicitly_disabled" {
  command = plan

  variables {
    auth_settings = { enabled = false }
  }

  assert {
    condition = (
      !local.auth_settings_v2.auth_enabled &&
      !local.auth_settings_v2.require_authentication &&
      local.auth_settings_v2.redirect_to_provider == null &&
      local.auth_settings_v2.identity_providers.azure_active_directory == null &&
      length(local.auth_settings_v2.identity_providers.custom_open_id_connect_providers) == 0 &&
      length(local.auth_app_settings) == 0
    )
    error_message = "Disabled authentication must not require a provider, redirect, or secret."
  }
}

run "microsoft_entra_only" {
  command = plan

  variables {
    auth_settings = {
      enabled = true
      microsoft_entra = {
        client_id            = "00000000-0000-0000-0000-000000000000"
        client_secret        = "entra-test-secret"
        tenant_auth_endpoint = "https://login.microsoftonline.com/00000000-0000-0000-0000-000000000000/v2.0"
      }
    }
  }

  assert {
    condition = (
      local.auth_settings_v2.auth_enabled &&
      local.auth_settings_v2.require_authentication &&
      local.auth_settings_v2.redirect_to_provider == "azureactivedirectory" &&
      local.auth_settings_v2.identity_providers.azure_active_directory.enabled &&
      local.auth_settings_v2.identity_providers.azure_active_directory.registration.client_id == var.auth_settings.microsoft_entra.client_id &&
      local.auth_settings_v2.identity_providers.azure_active_directory.registration.open_id_issuer == var.auth_settings.microsoft_entra.tenant_auth_endpoint &&
      length(local.auth_settings_v2.identity_providers.custom_open_id_connect_providers) == 0
    )
    error_message = "The default Entra provider must map to Azure's provider name and registration."
  }

  assert {
    condition = (
      local.auth_app_settings[local.auth_settings_v2.identity_providers.azure_active_directory.registration.client_secret_setting_name] == "entra-test-secret" &&
      issensitive(local.auth_app_settings["MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"])
    )
    error_message = "The Entra secret reference must resolve to a sensitive app setting."
  }

  assert {
    condition     = !issensitive(local.auth_settings_v2) && !strcontains(jsonencode(local.auth_settings_v2), "entra-test-secret")
    error_message = "AVM authentication metadata must be non-sensitive and contain no client secret."
  }
}

run "custom_oidc_only" {
  command = plan

  variables {
    auth_settings = {
      enabled          = true
      default_provider = "keycloak"
      custom_open_id_connect_providers = {
        keycloak = {
          client_id                        = "acmebot"
          client_secret                    = "keycloak-test-secret"
          well_known_open_id_configuration = "https://sso.example.com/realms/example/.well-known/openid-configuration"
        }
      }
    }
  }

  assert {
    condition = (
      local.auth_settings_v2.redirect_to_provider == "keycloak" &&
      local.auth_settings_v2.identity_providers.azure_active_directory == null &&
      local.auth_settings_v2.identity_providers.custom_open_id_connect_providers.keycloak.enabled &&
      local.auth_settings_v2.identity_providers.custom_open_id_connect_providers.keycloak.registration.client_id == "acmebot" &&
      local.auth_settings_v2.identity_providers.custom_open_id_connect_providers.keycloak.registration.client_credential.method == "ClientSecretPost" &&
      local.auth_settings_v2.identity_providers.custom_open_id_connect_providers.keycloak.registration.open_id_connect_configuration.well_known_open_id_configuration == var.auth_settings.custom_open_id_connect_providers.keycloak.well_known_open_id_configuration
    )
    error_message = "OIDC-only authentication must configure the selected provider and omit Entra."
  }

  assert {
    condition = (
      length(local.auth_app_settings) == 1 &&
      local.auth_app_settings[local.auth_settings_v2.identity_providers.custom_open_id_connect_providers.keycloak.registration.client_credential.client_secret_setting_name] == "keycloak-test-secret" &&
      issensitive(local.auth_app_settings["CUSTOM_OIDC_keycloak_AUTHENTICATION_SECRET"])
    )
    error_message = "The OIDC credential must resolve to its own sensitive app setting."
  }

  assert {
    condition     = !issensitive(local.auth_settings_v2) && !strcontains(jsonencode(local.auth_settings_v2), "keycloak-test-secret")
    error_message = "OIDC metadata must be non-sensitive and contain no client secret."
  }
}

run "combined_providers" {
  command = plan

  variables {
    auth_settings = {
      enabled          = true
      default_provider = "keycloak"
      microsoft_entra = {
        client_id            = "00000000-0000-0000-0000-000000000000"
        client_secret        = "entra-test-secret"
        tenant_auth_endpoint = "https://login.microsoftonline.com/00000000-0000-0000-0000-000000000000/v2.0"
      }
      custom_open_id_connect_providers = {
        keycloak = {
          client_id                        = "acmebot"
          client_secret                    = "keycloak-test-secret"
          well_known_open_id_configuration = "https://sso.example.com/realms/example/.well-known/openid-configuration"
        }
        MICROSOFT_PROVIDER = {
          client_id                        = "another-client"
          client_secret                    = "another-test-secret"
          well_known_open_id_configuration = "https://other.example.com/.well-known/openid-configuration"
        }
      }
    }
  }

  assert {
    condition = (
      local.auth_settings_v2.redirect_to_provider == "keycloak" &&
      local.auth_settings_v2.identity_providers.azure_active_directory.enabled &&
      length(local.auth_settings_v2.identity_providers.custom_open_id_connect_providers) == 2 &&
      length(local.auth_app_settings) == 3 &&
      local.auth_app_settings["MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"] == "entra-test-secret" &&
      local.auth_app_settings["CUSTOM_OIDC_keycloak_AUTHENTICATION_SECRET"] == "keycloak-test-secret" &&
      local.auth_app_settings["CUSTOM_OIDC_MICROSOFT_PROVIDER_AUTHENTICATION_SECRET"] == "another-test-secret"
    )
    error_message = "Combined providers must keep independent secrets without overwriting Entra's setting."
  }

  assert {
    condition     = !issensitive(local.auth_settings_v2) && issensitive(local.auth_app_settings)
    error_message = "Only the secret app settings should retain sensitivity."
  }
}

run "enabled_authentication_requires_provider" {
  command = plan
  variables {
    auth_settings = { enabled = true }
  }
  expect_failures = [var.auth_settings]
}

run "default_provider_must_exist" {
  command = plan
  variables {
    auth_settings = {
      enabled          = true
      default_provider = "missing"
    }
  }
  expect_failures = [var.auth_settings]
}

run "custom_provider_name_is_reserved" {
  command = plan
  variables {
    auth_settings = {
      enabled          = true
      default_provider = "MICROSOFT_ENTRA"
      custom_open_id_connect_providers = {
        MICROSOFT_ENTRA = {
          client_id                        = "acmebot"
          client_secret                    = "test-secret"
          well_known_open_id_configuration = "https://sso.example.com/.well-known/openid-configuration"
        }
      }
    }
  }
  expect_failures = [var.auth_settings]
}

run "oidc_client_secret_is_required" {
  command = plan
  variables {
    auth_settings = {
      enabled          = true
      default_provider = "keycloak"
      custom_open_id_connect_providers = {
        keycloak = {
          client_id                        = "acmebot"
          client_secret                    = null
          well_known_open_id_configuration = "https://sso.example.com/.well-known/openid-configuration"
        }
      }
    }
  }
  expect_failures = [var.auth_settings]
}

run "oidc_configuration_url_is_required" {
  command = plan
  variables {
    auth_settings = {
      enabled          = true
      default_provider = "keycloak"
      custom_open_id_connect_providers = {
        keycloak = {
          client_id                        = "acmebot"
          client_secret                    = "test-secret"
          well_known_open_id_configuration = null
        }
      }
    }
  }
  expect_failures = [var.auth_settings]
}

run "null_oidc_provider_is_rejected" {
  command = plan
  variables {
    auth_settings = {
      enabled                          = true
      default_provider                 = "keycloak"
      custom_open_id_connect_providers = { keycloak = null }
    }
  }
  expect_failures = [var.auth_settings]
}

run "configured_provider_requires_credentials_when_disabled" {
  command = plan
  variables {
    auth_settings = {
      enabled = false
      microsoft_entra = {
        client_id            = null
        client_secret        = "test-secret"
        tenant_auth_endpoint = "https://login.microsoftonline.com/00000000-0000-0000-0000-000000000000/v2.0"
      }
    }
  }
  expect_failures = [var.auth_settings]
}

run "azure_active_directory_provider_name_is_reserved" {
  command = plan
  variables {
    auth_settings = {
      enabled          = true
      default_provider = "AzureActiveDirectory"
      custom_open_id_connect_providers = {
        AzureActiveDirectory = {
          client_id                        = "acmebot"
          client_secret                    = "test-secret"
          well_known_open_id_configuration = "https://sso.example.com/.well-known/openid-configuration"
        }
      }
    }
  }
  expect_failures = [var.auth_settings]
}

run "custom_provider_name_cannot_contain_hyphens" {
  command = plan
  variables {
    auth_settings = {
      enabled          = true
      default_provider = "key-cloak"
      custom_open_id_connect_providers = {
        key-cloak = {
          client_id                        = "acmebot"
          client_secret                    = "test-secret"
          well_known_open_id_configuration = "https://sso.example.com/.well-known/openid-configuration"
        }
      }
    }
  }
  expect_failures = [var.auth_settings]
}

run "custom_provider_name_cannot_be_empty_when_disabled" {
  command = plan
  variables {
    auth_settings = {
      enabled = false
      custom_open_id_connect_providers = {
        "" = {
          client_id                        = "acmebot"
          client_secret                    = "test-secret"
          well_known_open_id_configuration = "https://sso.example.com/.well-known/openid-configuration"
        }
      }
    }
  }
  expect_failures = [var.auth_settings]
}

run "custom_provider_name_cannot_contain_path_separators" {
  command = plan
  variables {
    auth_settings = {
      enabled          = true
      default_provider = "key/cloak"
      custom_open_id_connect_providers = {
        "key/cloak" = {
          client_id                        = "acmebot"
          client_secret                    = "test-secret"
          well_known_open_id_configuration = "https://sso.example.com/.well-known/openid-configuration"
        }
      }
    }
  }
  expect_failures = [var.auth_settings]
}

run "custom_provider_name_supports_letters_digits_periods_and_underscores" {
  command = plan
  variables {
    auth_settings = {
      enabled          = true
      default_provider = "Keycloak_2.0"
      custom_open_id_connect_providers = {
        "Keycloak_2.0" = {
          client_id                        = "acmebot"
          client_secret                    = "test-secret"
          well_known_open_id_configuration = "https://sso.example.com/.well-known/openid-configuration"
        }
      }
    }
  }
  assert {
    condition = (
      local.auth_settings_v2.redirect_to_provider == "Keycloak_2.0" &&
      local.auth_settings_v2.identity_providers.custom_open_id_connect_providers["Keycloak_2.0"].registration.client_credential.client_secret_setting_name == "CUSTOM_OIDC_Keycloak_2.0_AUTHENTICATION_SECRET" &&
      local.auth_app_settings["CUSTOM_OIDC_Keycloak_2.0_AUTHENTICATION_SECRET"] == "test-secret"
    )
    error_message = "Supported provider names must be preserved in the login redirect and generated secret reference."
  }
}
