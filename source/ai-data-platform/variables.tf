variable "location" {
  type = string
}

variable "hub_vnet_name" {
  type = string
}

variable "kv_private_dns_zone_name" {
  type = string
}

variable "hub_openai_private_dns_zone_name" {
  type = string
}

variable "hub_private_endpoints_subnet_id" {
  type = string
}

variable "create_keyvault" {
  type    = bool
  default = false
}

variable "place_private_endpoints_in_hub" {
  type    = bool
  default = false
}

variable "create_databricks" {
  type    = bool
  default = false
}

variable "platfrom_name" {
  type = string
}

variable "hub_resource_group_name" {
  type = string
}

variable "hub_resource_group_name" {
  type = string
}

variable "env_name" {
  type = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.env_name)
    error_message = "Environment must be one of: dev, test, prod"
  }
}
