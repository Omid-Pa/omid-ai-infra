variable "location" { type = string }
variable "env_name" { type = string }
variable "platform_name" { type = string }
variable "spoke_rg_name" { type = string }

variable "spoke_vnet_name" { type = string }
variable "spoke_vnet_prefix" { type = string }

variable "platform_subnet_prefix" { type = string }
variable "pe_subnet_prefix" { type = string }
variable "bastion_subnet_prefix" { type = string }

# Hub connectivity inputs (required)
variable "hub_vnet_id" { type = string }
variable "hub_resource_group_name" { type = string }

# Private DNS zones (names + resource group) - these are the hub zones created in hub module
# Example: ["privatelink.vaultcore.azure.net","privatelink.openai.azure.com"]
variable "hub_private_dns_zone_names" {
  type = list(string)
}

# If you want to create a Key Vault in the spoke:
variable "create_keyvault" {
  type    = bool
  default = false
}
variable "spoke_keyvault_name" {
  type    = string
  default = ""
}

# Control where Private Endpoints for spoke Key Vault are placed:
# - if true: create PE in hub_private_endpoints_subnet_id (hub-managed)
# - if false: create PE in this spoke's private_endpoints subnet
variable "place_private_endpoints_in_hub" {
  type    = bool
  default = false
}
variable "hub_private_endpoints_subnet_id" {
  type    = string
  default = ""
}
