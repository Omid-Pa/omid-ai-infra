variable "location" { type = string }
variable "env_name" { type = string }
variable "platform_name" { type = string }
variable "spoke_rg_name" { type = string }

variable "spoke_vnet_name" { type = string }
variable "spoke_vnet_prefix" { type = string }

variable "platform_subnet_prefix" { type = string }
variable "pe_subnet_prefix" { type = string }
variable "bastion_subnet_prefix" { type = string }

variable "hub_vnet_name" { type = string }
variable "hub_resource_group_name" { type = string }

variable "hub_private_dns_zone_names" {
  type = list(string)
}

variable "create_keyvault" {
  type    = bool
  default = false
}
variable "spoke_keyvault_name" {
  type    = string
  default = ""
}

variable "place_private_endpoints_in_hub" {
  type    = bool
  default = false
}

variable "create_databricks" {
  type    = bool
  default = false
}

variable "databricks_workspace_name" {
  type    = string
  default = ""
}

variable "databricks_sku" {
  type    = string
  default = "standard"
}

variable "hub_keyvault_name" {
  type = string
}

variable "hub_openai_account_name" {
  type = string
}

variable "hub_private_endpoints_subnet_name" {
  type = string
}