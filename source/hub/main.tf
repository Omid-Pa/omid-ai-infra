module "hub" {
  source = "./modules/hub"
  
  env_name = var.env_name
  location           = var.location
  hub_rg_name        = "rg-hub-network-${var.env_name}"
  hub_vnet_name      = "hub-vnet-${var.env_name}"
  hub_vnet_prefix    = "10.0.0.0/16"
  pe_subnet_prefix   = "10.0.1.0/24"
  shared_subnet_prefix = "10.0.2.0/24"

  keyvault_name      = "kv-shared-hub-${var.env_name}"
  openai_name        = "openai-hub-ai-${var.env_name}" 
}
