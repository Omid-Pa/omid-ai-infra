data "azurerm_client_config" "current" {}

data "azurerm_virtual_network" "hub_vnet" {
  name                = var.hub_vnet_name
  resource_group_name = var.hub_resource_group_name
}

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
  name                              = "snet-workloads-${var.platform_name}-${var.env_name}"
  resource_group_name               = azurerm_resource_group.spoke.name
  virtual_network_name              = azurerm_virtual_network.spoke_vnet.name
  address_prefixes                  = [var.platform_subnet_prefix]
  private_endpoint_network_policies = "Disabled"
}

# Subnet: private endpoints (if not centralizing to hub)
resource "azurerm_subnet" "private_endpoints" {
  name                              = "snet-private-endpoints-${var.platform_name}-${var.env_name}"
  resource_group_name               = azurerm_resource_group.spoke.name
  virtual_network_name              = azurerm_virtual_network.spoke_vnet.name
  address_prefixes                  = [var.pe_subnet_prefix]
  private_endpoint_network_policies = "Disabled"
}

# Subnet: bastion / management
resource "azurerm_subnet" "bastion" {
  name                 = "snet-bastion-${var.platform_name}-${var.env_name}"
  resource_group_name  = azurerm_resource_group.spoke.name
  virtual_network_name = azurerm_virtual_network.spoke_vnet.name
  address_prefixes     = [var.bastion_subnet_prefix]
}

# NSG for platform subnet
resource "azurerm_network_security_group" "platform_nsg" {
  name                = "nsg-workloads-${var.platform_name}-${var.env_name}"
  resource_group_name = azurerm_resource_group.spoke.name
  location            = var.location

  security_rule {
    name                       = "AllowHTTPSOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "ServiceTag:Storage"
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "platform_assoc" {
  subnet_id                 = azurerm_subnet.platform.id
  network_security_group_id = azurerm_network_security_group.platform_nsg.id
}

# Spoke -> Hub
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "${var.spoke_vnet_name}-to-hub"
  resource_group_name       = azurerm_resource_group.spoke.name
  virtual_network_name      = azurerm_virtual_network.spoke_vnet.name
  remote_virtual_network_id = azurerm_virtual_network.hub_vnet.id

  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# Hub -> Spoke (if same subscription)
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "hub-to-${var.spoke_vnet_name}"
  resource_group_name       = var.hub_resource_group_name
  virtual_network_name      = var.hub_vnet_name
  remote_virtual_network_id = azurerm_virtual_network.spoke_vnet.id

  allow_forwarded_traffic      = true
  allow_virtual_network_access = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# Private DNS Zone Linking to spoke vent
resource "azurerm_private_dns_zone_virtual_network_link" "hub_zone_links" {
  for_each              = toset(var.hub_private_dns_zone_names)
  name                  = "link-${replace(each.value, ".", "-")}-${var.platform_name}-${var.env_name}"
  resource_group_name   = var.hub_resource_group_name
  private_dns_zone_name = each.value
  virtual_network_id    = azurerm_virtual_network.spoke_vnet.id
  registration_enabled  = false
}

# Optional Key Vault
resource "azurerm_key_vault" "spoke_kv" {
  count                         = var.create_keyvault ? 1 : 0
  name                          = var.spoke_keyvault_name
  location                      = var.location
  resource_group_name           = azurerm_resource_group.spoke.name
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  sku_name                      = "standard"
  public_network_access_enabled = false

  network_acls {
    default_action             = "Deny"
    bypass                     = "AzureServices"
    virtual_network_subnet_ids = []
  }

  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  rbac_authorization_enabled = true
}

data "azurerm_private_dns_zone" "kv_priv_hub" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.hub_resource_group_name
}

data "azurerm_subnet" "hub_private_endpoints" {
  name                 = var.hub_private_endpoints_subnet_name
  virtual_network_name = var.hub_vnet_name
  resource_group_name  = var.hub_resource_group_name
}

# Private Endpoint for Key Vault
resource "azurerm_private_endpoint" "spoke_kv_pe" {
  count               = var.create_keyvault ? 1 : 0
  name                = "pe-spoke-kv-${var.platform_name}-${var.env_name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.spoke.name

  # Decide where the private endpoint NIC will live(Place PE in hub subnet or Place PE in spoke subnet)
  subnet_id = var.place_private_endpoints_in_hub && var.hub_private_endpoints_subnet_id != "" ? var.hub_private_endpoints_subnet_id : azurerm_subnet.private_endpoints.id


  private_service_connection {
    name                           = "spoke-kv-psc-${var.platform_name}-${var.env_name}"
    private_connection_resource_id = element(azurerm_key_vault.spoke_kv.*.id, 0)
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "spoke-kv-dns-${var.platform_name}-${var.env_name}"
    private_dns_zone_ids = [data.azurerm_private_dns_zone.kv_priv_hub.id]
  }
}

# Optional databrick
resource "azurerm_databricks_workspace" "workspace" {
  count               = var.create_databricks ? 1 : 0
  name                = var.databricks_workspace_name
  resource_group_name = azurerm_resource_group.spoke.name
  location            = var.location
  sku                 = var.databricks_sku

  custom_parameters {
    virtual_network_id  = azurerm_virtual_network.spoke_vnet.id
    public_subnet_name  = azurerm_subnet.platform.name
    private_subnet_name = azurerm_subnet.platform.name
  }
}

# Provide access for Terraform to create Notebook + Job (inside Databricks)
provider "databricks" {
  host                        = var.create_databricks ? azurerm_databricks_workspace.workspace[0].workspace_url : null
  azure_workspace_resource_id = var.create_databricks ? azurerm_databricks_workspace.workspace[0].id : null
  azure_use_msi               = true
}

# RBAC
data "azuread_group" "team_contributor" {
  display_name     = "${var.platform_name}-${var.env_name}-contributor"
  security_enabled = true
}

data "azuread_group" "team_owner" {
  display_name     = "${var.platform_name}-${var.env_name}-owner"
  security_enabled = true
}

data "azurerm_key_vault" "hub_kv" {
  name                = var.hub_keyvault_name
  resource_group_name = var.hub_resource_group_name
}

# Give access to databrick
resource "azurerm_role_assignment" "team_owner_databricks_owner" {
  scope                = azurerm_databricks_workspace.workspace[0].id
  name                 = uuidv5("oid", join("", ["Owner", azurerm_databricks_workspace.this.id, data.azuread_group.team_owner.object_id]))
  role_definition_name = "Owner"
  principal_id         = data.azuread_group.team_owner.object_id
}

# Give access to spoke kv
resource "azurerm_role_assignment" "team_owner_kv_administrator" {
  scope                = azurerm_key_vault.spoke_kv[0].id
  name                 = uuidv5("oid", join("", ["Key Vault Administrator", azurerm_key_vault.spoke_kv.id, data.azuread_group.team_owner.object_id]))
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azuread_group.team_owner.object_id
}

resource "azurerm_role_assignment" "team_contributor_kv_contributor" {
  scope                = azurerm_key_vault.spoke_kv[0].id
  name                 = uuidv5("oid", join("", ["Key Vault Contributor", azurerm_key_vault.spoke_kv.id, data.azuread_group.team_contributor]))
  role_definition_name = "Key Vault Contributor"
  principal_id         = data.azuread_group.team_contributor
}

# Give access to hub kv
resource "azurerm_role_assignment" "team_owner_hub_kv_user" {
  scope                = data.azurerm_key_vault.hub_kv.id
  name                 = uuidv5("oid", join("", ["Key Vault Secrets User", data.azurerm_key_vault.hub_kv.id, data.azuread_group.team_owner.object_id]))
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.azuread_group.team_owner.object_id
}

resource "azurerm_role_assignment" "team_contributor_hub_kv_contributor" {
  scope                = data.azurerm_key_vault.hub_kv.id
  name                 = uuidv5("oid", join("", ["Key Vault Secrets User", data.azurerm_key_vault.hub_kv.id, data.azuread_group.team_contributor]))
  role_definition_name = "Key Vault Secrets User"
  principal_id         = data.azuread_group.team_contributor
}

# Give access to hub open-ai
resource "azurerm_role_assignment" "team_owner_openai_contributor" {
  scope                = data.azurerm_cognitive_account.hub_openai.id
  name                 = uuidv5("oid", join("", ["Cognitive Services OpenAI Contributor", data.azurerm_cognitive_account.hub_openai.id, data.azuread_group.team_owner.object_id]))
  role_definition_name = "Cognitive Services OpenAI Contributor"
  principal_id         = data.azuread_group.team_owner.object_id
}

resource "azurerm_role_assignment" "team_contributor_openai_user" {
  scope                = data.azurerm_cognitive_account.hub_openai.id
  name                 = uuidv5("oid", join("", ["Cognitive Services User", data.azurerm_cognitive_account.hub_openai.id, data.azuread_group.team_contributor.object_id]))
  role_definition_name = "Cognitive Services User"
  principal_id         = data.azuread_group.team_contributor.object_id
}
