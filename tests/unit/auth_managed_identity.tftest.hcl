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
    user_assigned_resource_ids = [
      "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-identity/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-easy-auth"
    ]
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

run "microsoft_entra_managed_identity" {
  command = plan

  override_module {
    override_during = plan
    target          = module.this
    outputs = {
      resource_id                     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-acmebot-test/providers/Microsoft.Web/sites/func-acmebot-test"
      system_assigned_mi_principal_id = "22222222-2222-2222-2222-222222222222"
    }
  }

  override_data {
    override_during = plan
    target          = data.azapi_resource.function_app_identity
    values = {
      output = {
        identity = {
          userAssignedIdentities = {
            "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-identity/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-easy-auth" = {
              clientId = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
            }
          }
        }
      }
    }
  }

  variables {
    managed_identities = {
      user_assigned_resource_ids = [
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-identity/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-easy-auth"
      ]
    }
    auth_settings = {
      enabled = true
      microsoft_entra = {
        client_id                  = "00000000-0000-0000-0000-000000000000"
        managed_identity_client_id = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
        tenant_auth_endpoint       = "https://login.microsoftonline.com/00000000-0000-0000-0000-000000000000/v2.0"
      }
      custom_open_id_connect_providers = {
        keycloak = {
          client_id                        = "acmebot"
          client_secret                    = "keycloak-test-secret"
          well_known_open_id_configuration = "https://sso.example.com/.well-known/openid-configuration"
        }
      }
    }
  }

  assert {
    condition = (
      local.auth_settings_v2.identity_providers.azure_active_directory.registration.client_secret_setting_name == "OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID" &&
      local.function_app_settings["OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID"] == "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa" &&
      !contains(keys(local.function_app_settings), "MICROSOFT_PROVIDER_AUTHENTICATION_SECRET") &&
      !contains(keys(local.function_app_settings), "Acmebot__ManagedIdentityClientId") &&
      !contains(keys(local.function_app_settings), "AzureWebJobsStorage__clientId")
    )
    error_message = "Easy Auth must use its own identity without creating an Entra secret or changing Acmebot/Storage identities."
  }

  assert {
    condition = (
      !issensitive(local.auth_settings_v2) &&
      local.auth_app_settings["CUSTOM_OIDC_keycloak_AUTHENTICATION_SECRET"] == "keycloak-test-secret" &&
      issensitive(local.auth_app_settings["CUSTOM_OIDC_keycloak_AUTHENTICATION_SECRET"])
    )
    error_message = "MI-based Entra authentication must coexist with sensitive custom OIDC credentials and non-sensitive AVM metadata."
  }
}

run "entra_credentials_are_mutually_exclusive" {
  command = plan
  variables {
    auth_settings = {
      enabled = true
      microsoft_entra = {
        client_id                  = "00000000-0000-0000-0000-000000000000"
        client_secret              = "test-secret"
        managed_identity_client_id = "11111111-1111-1111-1111-111111111111"
        tenant_auth_endpoint       = "https://login.microsoftonline.com/00000000-0000-0000-0000-000000000000/v2.0"
      }
    }
  }
  expect_failures = [var.auth_settings]
}

run "entra_requires_one_credential" {
  command = plan
  variables {
    auth_settings = {
      enabled = false
      microsoft_entra = {
        client_id            = "00000000-0000-0000-0000-000000000000"
        tenant_auth_endpoint = "https://login.microsoftonline.com/00000000-0000-0000-0000-000000000000/v2.0"
      }
    }
  }
  expect_failures = [var.auth_settings]
}

run "entra_managed_identity_client_id_requires_uuid" {
  command = plan
  variables {
    auth_settings = {
      enabled = true
      microsoft_entra = {
        client_id                  = "00000000-0000-0000-0000-000000000000"
        managed_identity_client_id = "not-a-guid"
        tenant_auth_endpoint       = "https://login.microsoftonline.com/00000000-0000-0000-0000-000000000000/v2.0"
      }
    }
  }
  expect_failures = [var.auth_settings]
}

run "entra_managed_identity_must_be_attached" {
  command = apply
  override_module {
    override_during = plan
    target          = module.this
    outputs = {
      resource_id                     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-acmebot-test/providers/Microsoft.Web/sites/func-acmebot-test"
      system_assigned_mi_principal_id = "22222222-2222-2222-2222-222222222222"
    }
  }

  # Exercise the postcondition after apply, when the Function App identity is read.
  # Replace the hosting modules to keep this an isolated, provider-mocked check.
  override_module {
    target = module.storage
    outputs = {
      private_endpoints = {}
      name              = "stacmebottest"
      resource_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-acmebot-test/providers/Microsoft.Storage/storageAccounts/stacmebottest"
      resource = {
        output = {
          properties = {
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
  override_module {
    target = module.serverfarm
    outputs = {
      resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-acmebot-test/providers/Microsoft.Web/serverfarms/asp-acmebottest"
    }
  }

  variables {
    skip_package_deployment = true
    application_insights = {
      resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-observability/providers/Microsoft.Insights/components/appi-existing"
    }
    managed_identities = {
      user_assigned_resource_ids = [
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-identity/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-other"
      ]
    }
    auth_settings = {
      enabled = true
      microsoft_entra = {
        client_id                  = "00000000-0000-0000-0000-000000000000"
        managed_identity_client_id = "11111111-1111-1111-1111-111111111111"
        tenant_auth_endpoint       = "https://login.microsoftonline.com/00000000-0000-0000-0000-000000000000/v2.0"
      }
    }
  }
  expect_failures = [data.azapi_resource.function_app_identity]
}

run "easy_auth_identity_setting_is_reserved" {
  command = plan
  variables {
    additional_app_settings = {
      OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID = "11111111-1111-1111-1111-111111111111"
    }
  }
  expect_failures = [var.additional_app_settings]
}

run "entra_managed_identity_requires_an_assignment" {
  command = plan
  variables {
    managed_identities = { system_assigned = true }
    auth_settings = {
      enabled = true
      microsoft_entra = {
        client_id                  = "00000000-0000-0000-0000-000000000000"
        managed_identity_client_id = "11111111-1111-1111-1111-111111111111"
        tenant_auth_endpoint       = "https://login.microsoftonline.com/00000000-0000-0000-0000-000000000000/v2.0"
      }
    }
  }
  expect_failures = [var.auth_settings]
}

run "entra_managed_identity_matches_attached_identity" {
  command = apply
  override_module {
    override_during = plan
    target          = module.this
    outputs = {
      resource_id                     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-acmebot-test/providers/Microsoft.Web/sites/func-acmebot-test"
      system_assigned_mi_principal_id = "22222222-2222-2222-2222-222222222222"
    }
  }

  # Exercise the postcondition after apply, when the Function App identity is read.
  # Replace the hosting modules to keep this an isolated, provider-mocked check.
  override_module {
    target = module.storage
    outputs = {
      private_endpoints = {}
      name              = "stacmebottest"
      resource_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-acmebot-test/providers/Microsoft.Storage/storageAccounts/stacmebottest"
      resource = {
        output = {
          properties = {
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
  override_module {
    target = module.serverfarm
    outputs = {
      resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-acmebot-test/providers/Microsoft.Web/serverfarms/asp-acmebottest"
    }
  }

  variables {
    skip_package_deployment = true
    application_insights = {
      resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-observability/providers/Microsoft.Insights/components/appi-existing"
    }
    managed_identities = {
      user_assigned_resource_ids = [
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-identity/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-easy-auth"
      ]
    }
    auth_settings = {
      enabled = true
      microsoft_entra = {
        client_id                  = "00000000-0000-0000-0000-000000000000"
        managed_identity_client_id = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
        tenant_auth_endpoint       = "https://login.microsoftonline.com/00000000-0000-0000-0000-000000000000/v2.0"
      }
    }
  }
  override_data {
    target = data.azapi_resource.function_app_identity
    values = {
      output = {
        identity = {
          userAssignedIdentities = {
            "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-identity/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-easy-auth" = {
              clientId = "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"
            }
          }
        }
      }
    }
  }
  assert {
    condition     = local.function_app_settings["OVERRIDE_USE_MI_FIC_ASSERTION_CLIENTID"] == "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa"
    error_message = "An attached identity must pass the postcondition regardless of client ID case."
  }
}
