terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0, < 5.0.0"    # range
    }
  }
}

resource "azurerm_storage_account" "this" {
  name                     = var.name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_kind             = "StorageV2"
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
  min_tls_version          = "TLS1_2"
  enable_https_traffic_only = true
  allow_blob_public_access = false
  shared_access_key_enabled = var.shared_access_key_enabled
  default_to_oauth_authentication = true
  cross_tenant_replication_enabled = false

  network_rules {
    default_action             = var.network_default_action
    bypass                     = ["AzureServices"]
    ip_rules                   = var.ip_rules
    virtual_network_subnet_ids = var.subnet_ids
  }

  blob_properties {
    versioning_enabled       = true
    change_feed_enabled      = true
    delete_retention_policy { days = 30 }
    container_delete_retention_policy { days = 7 }
  }

  tags = var.tags
}

# Optional CMK via Key Vault
resource "azurerm_storage_account_customer_managed_key" "cmk" {
  count                   = var.cmk_key_vault_key_id == null ? 0 : 1
  storage_account_id      = azurerm_storage_account.this.id
  key_vault_id            = split("/keys/", var.cmk_key_vault_key_id)[0]
  key_name                = split("/keys/", var.cmk_key_vault_key_id)[1]
  key_version             = null
  user_assigned_identity_id = var.user_assigned_identity_id
}

# Diagnostic settings
resource "azurerm_monitor_diagnostic_setting" "sa" {
  name                       = "ds-${var.name}"
  target_resource_id         = azurerm_storage_account.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log { category = "StorageRead" }
  enabled_log { category = "StorageWrite" }
  enabled_log { category = "StorageDelete" }

  metric {
    category = "Transaction"
    enabled  = true
  }
}