terraform {
  required_version = ">= 1.10.0, < 2.0.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = ">= 2.11.0, < 3.0.0"
    }
    modtm = {
      source  = "Azure/modtm"
      version = "~> 0.3"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0, < 4.0.0"
    }
  }
}
