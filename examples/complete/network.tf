# Hub/spoke networking is out of scope for this example; it provisions a single
# self-contained virtual network so the private deployment can be applied as-is.
resource "azurerm_virtual_network" "default" {
  name                = "vnet-acmebot-${random_string.random.result}"
  resource_group_name = azurerm_resource_group.default.name
  location            = azurerm_resource_group.default.location
  address_space       = ["10.0.0.0/16"]
  tags                = local.tags
}

# Flex Consumption VNET integration subnet. It must be delegated to
# Microsoft.App/environments, be at least /27, and cannot host private endpoints.
resource "azurerm_subnet" "functions" {
  name                 = "snet-functions"
  resource_group_name  = azurerm_resource_group.default.name
  virtual_network_name = azurerm_virtual_network.default.name
  address_prefixes     = ["10.0.0.0/26"]

  delegation {
    name = "Microsoft.App.environments"

    service_delegation {
      name    = "Microsoft.App/environments"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# Dedicated subnet for the Function App and Storage Account private endpoints.
resource "azurerm_subnet" "private_endpoints" {
  name                              = "snet-private-endpoints"
  resource_group_name               = azurerm_resource_group.default.name
  virtual_network_name              = azurerm_virtual_network.default.name
  address_prefixes                  = ["10.0.1.0/26"]
  private_endpoint_network_policies = "Disabled"
}

# Private DNS zones the module wires its private endpoints into, plus the Key
# Vault zone consumed by the example-managed Key Vault private endpoint.
resource "azurerm_private_dns_zone" "default" {
  for_each = local.private_dns_zones

  name                = each.value
  resource_group_name = azurerm_resource_group.default.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "default" {
  for_each = local.private_dns_zones

  name                  = "vnl-${each.key}"
  resource_group_name   = azurerm_resource_group.default.name
  private_dns_zone_name = azurerm_private_dns_zone.default[each.key].name
  virtual_network_id    = azurerm_virtual_network.default.id
  registration_enabled  = false
  tags                  = local.tags
}
