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
          clientId           = "11111111-1111-1111-1111-111111111111"
          principalId        = "22222222-2222-2222-2222-222222222222"
          ConnectionString   = "InstrumentationKey=33333333-3333-3333-3333-333333333333;IngestionEndpoint=https://eastus-0.in.applicationinsights.azure.com/"
          InstrumentationKey = "33333333-3333-3333-3333-333333333333"
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

run "default_inputs_plan_successfully" {
  command = plan
}

run "sovereign_environment_plan_successfully" {
  command = plan

  variables {
    acmebot = {
      version      = "5.0.1"
      mail_address = "test@example.com"
      vault_uri    = "https://kv-acmebot-test.vault.azure.us/"
      environment  = "AzureUSGovernment"

      dns_providers = {
        azure_dns = {
          subscription_id = "00000000-0000-0000-0000-000000000000"
        }
      }
    }
  }
}

run "parent_id_must_be_resource_group_id" {
  command = plan

  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/not-a-resource-group"
  }

  expect_failures = [var.parent_id]
}

run "private_defaults_require_function_private_endpoint" {
  command = plan

  variables {
    private_endpoints = {}
  }

  expect_failures = [var.public_network_access_enabled]
}

run "name_must_be_within_length" {
  command = plan

  variables {
    name = "a"
  }

  expect_failures = [var.name]
}

run "acmebot_version_must_be_semver" {
  command = plan

  variables {
    acmebot = {
      version      = "not-semver"
      mail_address = "test@example.com"
      vault_uri    = "https://kv-acmebot-test.vault.azure.net/"
      dns_providers = {
        azure_dns = {
          subscription_id = "00000000-0000-0000-0000-000000000000"
        }
      }
    }
  }

  expect_failures = [var.acmebot]
}

run "acmebot_mail_address_must_not_include_mailto_prefix" {
  command = plan

  variables {
    acmebot = {
      version      = "5.0.1"
      mail_address = "mailto:test@example.com"
      vault_uri    = "https://kv-acmebot-test.vault.azure.net/"
      dns_providers = {
        azure_dns = {
          subscription_id = "00000000-0000-0000-0000-000000000000"
        }
      }
    }
  }

  expect_failures = [var.acmebot]
}

run "acmebot_environment_must_be_supported" {
  command = plan

  variables {
    acmebot = {
      version      = "5.0.1"
      mail_address = "test@example.com"
      vault_uri    = "https://kv-acmebot-test.vault.azure.net/"
      environment  = "AzureMoonCloud"
      dns_providers = {
        azure_dns = {
          subscription_id = "00000000-0000-0000-0000-000000000000"
        }
      }
    }
  }

  expect_failures = [var.acmebot]
}

run "acmebot_renew_before_expiry_must_be_in_range" {
  command = plan

  variables {
    acmebot = {
      version             = "5.0.1"
      mail_address        = "test@example.com"
      vault_uri           = "https://kv-acmebot-test.vault.azure.net/"
      renew_before_expiry = 366
      dns_providers = {
        azure_dns = {
          subscription_id = "00000000-0000-0000-0000-000000000000"
        }
      }
    }
  }

  expect_failures = [var.acmebot]
}

run "acmebot_managed_identity_client_id_must_be_guid" {
  command = plan

  variables {
    acmebot = {
      version                    = "5.0.1"
      mail_address               = "test@example.com"
      vault_uri                  = "https://kv-acmebot-test.vault.azure.net/"
      managed_identity_client_id = "not-a-guid"
      dns_providers = {
        azure_dns = {
          subscription_id = "00000000-0000-0000-0000-000000000000"
        }
      }
    }
  }

  expect_failures = [var.acmebot]
}

run "acmebot_requires_at_least_one_dns_provider" {
  command = plan

  variables {
    acmebot = {
      version       = "5.0.1"
      mail_address  = "test@example.com"
      vault_uri     = "https://kv-acmebot-test.vault.azure.net/"
      dns_providers = {}
    }
  }

  expect_failures = [var.acmebot]
}

run "acmebot_external_account_binding_algorithm_must_be_supported" {
  command = plan

  variables {
    acmebot = {
      version      = "5.0.1"
      mail_address = "test@example.com"
      vault_uri    = "https://kv-acmebot-test.vault.azure.net/"
      external_account_binding = {
        key_id    = "test-key-id"
        hmac_key  = "test-hmac-key"
        algorithm = "HS1024"
      }
      dns_providers = {
        azure_dns = {
          subscription_id = "00000000-0000-0000-0000-000000000000"
        }
      }
    }
  }

  expect_failures = [var.acmebot]
}

run "acmebot_gandi_aliases_are_mutually_exclusive" {
  command = plan

  variables {
    acmebot = {
      version      = "5.0.1"
      mail_address = "test@example.com"
      vault_uri    = "https://kv-acmebot-test.vault.azure.net/"
      dns_providers = {
        gandi = {
          api_key = "test-api-key"
        }
        gandi_live_dns = {
          api_key = "test-api-key"
        }
      }
    }
  }

  expect_failures = [var.acmebot]
}

run "storage_account_name_must_be_lowercase_alphanumeric" {
  command = plan

  variables {
    virtual_network_subnet_id = null

    storage_account = {
      name                          = "BAD-NAME"
      public_network_access_enabled = true
    }
  }

  expect_failures = [var.storage_account]
}

run "storage_account_replication_type_must_be_allowed_value" {
  command = plan

  variables {
    virtual_network_subnet_id = null

    storage_account = {
      public_network_access_enabled = true
      account_replication_type      = "INVALID"
    }
  }

  expect_failures = [var.storage_account]
}

run "instance_memory_in_mb_must_be_supported_value" {
  command = plan

  variables {
    instance_memory_in_mb = 1024
  }

  expect_failures = [var.instance_memory_in_mb]
}

run "maximum_instance_count_must_be_in_range" {
  command = plan

  variables {
    maximum_instance_count = 2000
  }

  expect_failures = [var.maximum_instance_count]
}

run "log_analytics_workspace_retention_must_be_in_range" {
  command = plan

  variables {
    log_analytics_workspace = {
      retention_in_days = 10
    }
  }

  expect_failures = [var.log_analytics_workspace]
}

run "log_analytics_workspace_resource_id_must_be_workspace" {
  command = plan

  variables {
    log_analytics_workspace = {
      resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-observability/providers/Microsoft.Insights/components/appi-acmebot"
    }
  }

  expect_failures = [var.log_analytics_workspace]
}

run "application_insights_resource_id_must_be_component" {
  command = plan

  variables {
    application_insights = {
      resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-observability/providers/Microsoft.OperationalInsights/workspaces/log-acmebot"
    }
  }

  expect_failures = [var.application_insights]
}

run "existing_monitoring_resources_plan_successfully" {
  command = plan

  variables {
    log_analytics_workspace = {
      resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-observability/providers/Microsoft.OperationalInsights/workspaces/log-acmebot"
    }

    application_insights = {
      resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-observability/providers/Microsoft.Insights/components/appi-acmebot"
    }
  }
}

run "lock_kind_must_be_allowed_value" {
  command = plan

  variables {
    lock = {
      kind = "Invalid"
    }
  }

  expect_failures = [var.lock]
}

run "additional_app_settings_cannot_use_reserved_prefixes" {
  command = plan

  variables {
    additional_app_settings = {
      "Acmebot__Contacts" = "override@example.com"
    }
  }

  expect_failures = [var.additional_app_settings]
}

run "additional_app_settings_cannot_override_azure_web_jobs_storage" {
  command = plan

  variables {
    additional_app_settings = {
      "AzureWebJobsStorage__clientId" = "00000000-0000-0000-0000-000000000000"
    }
  }

  expect_failures = [var.additional_app_settings]
}

run "auth_settings_requires_client_secret" {
  command = plan

  variables {
    auth_settings = {
      enabled = true
      active_directory = {
        client_id            = "00000000-0000-0000-0000-000000000000"
        tenant_auth_endpoint = "https://login.microsoftonline.com/00000000-0000-0000-0000-000000000000/v2.0"
      }
    }
  }

  expect_failures = [var.auth_settings_client_secret]
}

run "system_assigned_disabled_requires_storage_identity" {
  command = plan

  variables {
    managed_identities = {
      system_assigned = false
      user_assigned_resource_ids = [
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-identity/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-acmebot"
      ]
    }

    acmebot = {
      version                    = "5.0.1"
      mail_address               = "test@example.com"
      vault_uri                  = "https://kv-acmebot-test.vault.azure.net/"
      managed_identity_client_id = "11111111-1111-1111-1111-111111111111"
      dns_providers = {
        azure_dns = {
          subscription_id = "00000000-0000-0000-0000-000000000000"
        }
      }
    }
  }

  expect_failures = [var.storage_managed_identity]
}

run "user_assigned_storage_identity_plan_successfully" {
  command = plan

  variables {
    managed_identities = {
      system_assigned = false
      user_assigned_resource_ids = [
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-identity/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-acmebot"
      ]
    }

    storage_managed_identity = {
      user_assigned_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-identity/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-acmebot"
    }

    acmebot = {
      version                    = "5.0.1"
      mail_address               = "test@example.com"
      vault_uri                  = "https://kv-acmebot-test.vault.azure.net/"
      managed_identity_client_id = "11111111-1111-1111-1111-111111111111"
      dns_providers = {
        azure_dns = {
          subscription_id = "00000000-0000-0000-0000-000000000000"
        }
      }
    }
  }
}

run "storage_user_assigned_identity_must_be_attached" {
  command = plan

  variables {
    storage_managed_identity = {
      user_assigned_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-identity/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-acmebot"
    }
  }

  expect_failures = [var.storage_managed_identity]
}

run "acmebot_managed_identity_client_id_required_without_system_assigned_identity" {
  command = plan

  variables {
    managed_identities = {
      system_assigned = false
      user_assigned_resource_ids = [
        "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-identity/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-acmebot"
      ]
    }

    storage_managed_identity = {
      user_assigned_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-identity/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-acmebot"
    }
  }

  expect_failures = [var.acmebot]
}

run "acmebot_managed_identity_client_id_requires_attached_identity" {
  command = plan

  variables {
    acmebot = {
      version                    = "5.0.1"
      mail_address               = "test@example.com"
      vault_uri                  = "https://kv-acmebot-test.vault.azure.net/"
      managed_identity_client_id = "00000000-0000-0000-0000-000000000000"
      dns_providers = {
        azure_dns = {
          subscription_id = "00000000-0000-0000-0000-000000000000"
        }
      }
    }
  }

  expect_failures = [var.acmebot]
}

run "virtual_network_subnet_id_must_be_subnet_resource_id" {
  command = plan

  variables {
    virtual_network_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/not-a-subnet"
  }

  expect_failures = [var.virtual_network_subnet_id]
}

run "function_app_private_endpoint_required_when_public_access_disabled" {
  command = plan

  variables {
    public_network_access_enabled = false
    private_endpoints             = {}
  }

  expect_failures = [var.public_network_access_enabled]
}

run "storage_public_access_disabled_requires_blob_queue_and_table_private_endpoints" {
  command = plan

  variables {
    storage_account = {
      public_network_access_enabled = false
      private_endpoints = {
        blob = {
          subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-storage-private-endpoints"
          subresource_name   = "blob"
        }
      }
    }
  }

  expect_failures = [var.storage_account]
}

run "storage_public_access_disabled_requires_virtual_network_integration" {
  command = plan

  variables {
    virtual_network_subnet_id = null

    storage_account = {
      public_network_access_enabled = false
      private_endpoints = {
        blob = {
          subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-storage-private-endpoints"
          subresource_name   = "blob"
        }
        queue = {
          subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-storage-private-endpoints"
          subresource_name   = "queue"
        }
        table = {
          subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-storage-private-endpoints"
          subresource_name   = "table"
        }
      }
    }
  }

  expect_failures = [var.virtual_network_subnet_id]
}

run "storage_network_rules_default_action_must_be_allowed_value" {
  command = plan

  variables {
    virtual_network_subnet_id = null

    storage_account = {
      public_network_access_enabled = true
      network_rules = {
        default_action = "Audit"
      }
    }
  }

  expect_failures = [var.storage_account]
}

run "storage_blob_delete_retention_days_must_be_in_range" {
  command = plan

  variables {
    virtual_network_subnet_id = null

    storage_account = {
      public_network_access_enabled = true
      blob_properties = {
        delete_retention_policy = {
          enabled = true
          days    = 366
        }
      }
    }
  }

  expect_failures = [var.storage_account]
}

run "storage_private_endpoint_requires_virtual_network_integration" {
  command = plan

  variables {
    virtual_network_subnet_id = null

    storage_account = {
      private_endpoints = {
        blob = {
          subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-storage-private-endpoints"
          subresource_name   = "blob"
        }
        queue = {
          subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-storage-private-endpoints"
          subresource_name   = "queue"
        }
        table = {
          subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-storage-private-endpoints"
          subresource_name   = "table"
        }
      }
    }
  }

  expect_failures = [var.virtual_network_subnet_id]
}

run "virtual_network_integration_requires_storage_private_endpoint" {
  command = plan

  variables {
    virtual_network_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-acmebot"
    storage_account = {
      public_network_access_enabled = true
      private_endpoints             = {}
    }
  }

  expect_failures = [var.virtual_network_subnet_id]
}

run "storage_private_endpoint_subnet_must_differ_from_integration_subnet" {
  command = plan

  variables {
    virtual_network_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-acmebot"
    storage_account = {
      public_network_access_enabled = true
      private_endpoints = {
        blob = {
          subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-network/providers/Microsoft.Network/virtualNetworks/vnet-acmebot/subnets/snet-acmebot"
          subresource_name   = "blob"
        }
      }
    }
  }

  expect_failures = [var.virtual_network_subnet_id]
}
