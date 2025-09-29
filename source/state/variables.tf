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