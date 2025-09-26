data "azurerm_client_config" "current" {}

# Spoke resource group
resource "azurerm_resource_group" "spoke" {
  name     = var.spoke_rg_name
  location = var.location
}

# Spoke VNet
resource "azurerm_virtual_network" "spoke_vnet" {
  name                = var.spoke_vnet_name
  resource_group_name = azurerm_resource_group.spoke.name
  location            = var.location
  address_space       = [var.spoke_vnet_prefix]
}

# Subnet: platform (for Databricks/workloads)
resource "azurerm_subnet" "platform" {
  name                 = "snet-${var.platform_name}-${var.env_name}"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke_vnet.name
  address_prefixes     = [var.platform_subnet_prefix]
}

# Subnet: platform (for Databricks/workloads)
resource "azurerm_subnet" "platform" {
  name                 = "snet-platform-${var.env_name}"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke_vnet.name
  address_prefixes     = [var.platform_subnet_prefix]
}

# Subnet: private endpoints (if not centralizing to hub)
resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints-${var.env_name}"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke_vnet.name
  address_prefixes     = [var.pe_subnet_prefix]
  private_endpoint_network_policies = "Disabled"
}

# Subnet: bastion / management
resource "azurerm_subnet" "bastion" {
  name                 = "snet-bastion-${var.env_name}"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke_vnet.name
  address_prefixes     = [var.bastion_subnet_prefix]
}