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
          InstrumentationKey  = "33333333-3333-3333-3333-333333333333"
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

run "plan" {
  command = plan

  module {
    source = "./tests/fixtures/application-insights-resource-id-unknown"
  }
}
