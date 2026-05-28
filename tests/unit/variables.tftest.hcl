provider "azurerm" {
  features {}

  skip_provider_registration = true
}

variables {
  name                = "func-acmebot-test"
  resource_group_name = "rg-acmebot-test"
  location            = "eastus"

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
}

run "default_inputs_plan_successfully" {
  command = plan
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

run "storage_account_name_must_be_lowercase_alphanumeric" {
  command = plan

  variables {
    storage_account = {
      name = "BAD-NAME"
    }
  }

  expect_failures = [var.storage_account]
}

run "storage_account_replication_type_must_be_allowed_value" {
  command = plan

  variables {
    storage_account = {
      account_replication_type = "INVALID"
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

run "virtual_network_subnet_id_must_be_subnet_resource_id" {
  command = plan

  variables {
    virtual_network_subnet_id = "/subscriptions/00000000-0000-0000-0000-000000000000/not-a-subnet"
  }

  expect_failures = [var.virtual_network_subnet_id]
}
