variable "location" {
  type = string
}

variable "env_name" {
  type = string

  validation {
    condition     = contains(["dev", "test", "prod"], var.env_name)
    error_message = "Environment must be one of: dev, test, prod"
  }
}

variable " hub_rg_name  " {
  type = string
}

variable "hub_vnet_name " {
  type = string
}

variable "hub_vnet_name" {
  type = string
}

variable "hub_vnet_prefix" {
  type = string
}

variable "pe_subnet_prefix " {
  type = string
}

variable "shared_subnet_prefix" {
  type = string
}

variable "keyvault_name" {
  type = string
}

variable "openai_name " {
  type = string
}