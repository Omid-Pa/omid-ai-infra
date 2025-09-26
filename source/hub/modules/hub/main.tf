# Resource Group for Hub
resource "azurerm_resource_group" "hub" {
  name     = var.hub_rg_name
  location = var.location
}

# Hub VNet
resource "azurerm_virtual_network" "hub" {
  name                = var.hub_vnet_name
  resource_group_name = azurerm_resource_group.hub.name
  location            = azurerm_resource_group.hub.location
  address_space       = [var.hub_vnet_prefix]
}

# Subnet For Private Endpoints
resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-hub-private-endpoints-${var.env_name}"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.pe_subnet_prefix]
}

# Subnet For Shared services
resource "azurerm_subnet" "shared_services" {
  name                 = "snet-hub-shared-services-${var.env_name}"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.shared_subnet_prefix]
}

# Private DNS zone for OpenAI
resource "azurerm_private_dns_zone" "openai_priv" {
  name                = "privatelink.openai.azure.com"
  resource_group_name = azurerm_resource_group.hub.name
}

# Private DNS zone for Key Vault
resource "azurerm_private_dns_zone" "kv_priv" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.hub.name
}

# Link DNS zones to the hub vnet
resource "azurerm_private_dns_zone_virtual_network_link" "openai_link_hub" {
  name                  = "link-openai-hub-${var.env_name}"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.openai_priv.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
}

resource "azurerm_private_dns_zone_virtual_network_link" "kv_link_hub" {
  name                  = "link-kv-hub-${var.env_name}"
  resource_group_name   = azurerm_resource_group.hub.name
  private_dns_zone_name = azurerm_private_dns_zone.kv_priv.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
}

data "azurerm_client_config" "current" {}

# Shared Key Vault (in hub)
resource "azurerm_key_vault" "hub_shared_kv" {
  name                = var.keyvault_name
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    virtual_network_subnet_ids = []
  }

  enabled_for_disk_encryption = true
  purge_protection_enabled    = true
  soft_delete_retention_days  = 7
  rbac_authorization_enabled  = true
}

# Private Endpoint for Key Vault and add a record to private dns zone
resource "azurerm_private_endpoint" "kv_pe" {
  name                = "pe-hub-kv-shared-${var.env_name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "hub-kv-priv-conn--${var.env_name}"
    private_connection_resource_id = azurerm_key_vault.shared.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "hub-kv-dns-${var.env_name}"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.kv.id
    ]
  }
}

# Create Azure OpenAI (Cognitive Services account with kind OpenAI)
# Note: this requires subscription permission/approval for OpenAI resource creation.
resource "azurerm_cognitive_account" "openai" {
  name                          = var.openai_name
  location                      = avr.location
  resource_group_name           = azurerm_resource_group.hub.name
  sku_name                      = "S0"
  kind                          = "OpenAI"
  public_network_access_enabled = false
  custom_subdomain_name         = "hub-shared-openai-${var.env_name}"

  identity {
    type = "SystemAssigned"
  }

}

# Private endpoint for OpenAI add a record to private dns zone
resource "azurerm_private_endpoint" "openai_pe" {
  name                = "pe-hub-openai-shared-${var.env_name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.hub.name
  subnet_id           = azurerm_subnet.private_endpoints.id

  private_service_connection {
    name                           = "hub-openai-priv-conn-${var.env_name}"
    private_connection_resource_id = azurerm_cognitive_account.openai.id
    subresource_names              = ["account"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name = "hub-openaikv-dns-${var.env_name}"
    private_dns_zone_ids = [
      azurerm_private_dns_zone.openai_priv.id
    ]
  }
}