module "spoke_mininganalytics" {
  source = "./modules/spoke"

  location          = var.location
  env_name          = var.env_name
  spoke_rg_name     = "rg-${var.platfrom_name}-${var.env_name}"
  spoke_vnet_name   = "vnet-${var.platfrom_name}-${var.env_name}"
  spoke_vnet_prefix = "10.1.0.0/16"

  platform_subnet_prefix = "10.1.1.0/24"
  pe_subnet_prefix       = "10.1.2.0/24"
  bastion_subnet_prefix  = "10.1.3.0/24"

  hub_vnet_name                     = var.hub_vnet_name
  hub_resource_group_name           = var.hub_resource_group_name
  hub_keyvault_name                 = var.hub_keyvault_name
  hub_openai_account_name           = var.hub_openai_account_name
  hub_private_endpoints_subnet_name = var.hub_private_endpoints_subnet_name

  hub_private_dns_zone_names = [
    var.kv_private_dns_zone_name,
    var.hub_openai_private_dns_zone_name
  ]

  # optional: create a Key Vault in spoke
  create_keyvault     = var.create_keyvault
  spoke_keyvault_name = "kv-${var.platfrom_name}-${var.env_name}"


  # optional: create a databrick in spoke
  create_databricks         = var.create_databricks
  databricks_workspace_name = "databrick-${var.platform_name}-${var.env_name}"
  databricks_sku            = var.databricks_sku

  # choose where to create PEs
  place_private_endpoints_in_hub = var.place_private_endpoints_in_hub
}
