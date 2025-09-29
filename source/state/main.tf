data "azuread_group" "owner" {
  display_name     = "hub-${var.env_name}-owner"
  security_enabled = true
}

resource "azurerm_resource_group" "state" {
  name     = "rg-state-hub-global-${var.env_name}"
  location = var.location

  lifecycle {
    ignore_changes = [tags]
  }
}

resource "azurerm_storage_account" "state" {
  name                     = "statehubglobal${var.env_name}"
  resource_group_name      = azurerm_resource_group.state.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  lifecycle {
    ignore_changes = [tags]
  }

  # Add security measures
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false # Need to be enabled manually on the portal to allow applying terraform by command without SP
  public_network_access_enabled   = false
  blob_properties {
    delete_retention_policy {
      days = 14
    }
  }
  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = []
  }
}

resource "azurerm_storage_container" "tfstate" {
  name               = "tfstate"
  storage_account_id = azurerm_storage_account.state.id
}

resource "azurerm_role_assignment" "storage_blob_data_owner" {
  scope                = azurerm_storage_account.state.id
  name                 = uuidv5("oid", join("", ["Storage Blob Data Owner", azurerm_storage_account.state.id, data.azuread_group.owner.object_id]))
  role_definition_name = "Storage Blob Data Owner"
  principal_id         = data.azuread_group.owner.object_id
}
