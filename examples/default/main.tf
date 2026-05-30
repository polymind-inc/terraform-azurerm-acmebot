provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

resource "random_string" "random" {
  length  = 4
  lower   = true
  upper   = false
  special = false
}

data "azurerm_client_config" "current" {
}

resource "azurerm_resource_group" "default" {
  name     = "rg-acmebot"
  location = "westus2"
}

resource "azurerm_key_vault" "default" {
  name                = "kv-acmebot-${random_string.random.result}"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location

  sku_name = "standard"

  rbac_authorization_enabled = true
  tenant_id                  = data.azurerm_client_config.current.tenant_id
}

resource "azurerm_role_assignment" "default" {
  scope                = azurerm_key_vault.default.id
  role_definition_name = "Key Vault Certificates Officer"
  principal_id         = module.acmebot.system_assigned_mi_principal_id
}

module "acmebot" {
  source = "../../"

  name                          = "func-acmebot-${random_string.random.result}"
  parent_id                     = azurerm_resource_group.default.id
  location                      = azurerm_resource_group.default.location
  maximum_instance_count        = 50
  instance_memory_in_mb         = 2048
  public_network_access_enabled = true
  tags = {
    workload = "acmebot"
  }

  acmebot = {
    version      = "5.0.0"
    mail_address = "admin@example.com"
    vault_uri    = azurerm_key_vault.default.vault_uri

    dns_providers = {
      azure_dns = {
        subscription_id = data.azurerm_client_config.current.subscription_id
      }
    }
  }

  managed_identities = {
    system_assigned = true
  }

  storage_account = {
    public_network_access_enabled = true
  }

  site_config = {
    ip_restriction_default_action     = "Allow"
    scm_ip_restriction_default_action = "Allow"
    scm_use_main_ip_restriction       = false
  }
}

output "system_assigned_mi_principal_id" {
  value     = module.acmebot.system_assigned_mi_principal_id
  sensitive = true
}
