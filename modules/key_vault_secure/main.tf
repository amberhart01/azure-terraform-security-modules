terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.112.0"
    }
  }
}

resource "azurerm_key_vault" "this" {
  name                        = var.name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  tenant_id                   = var.tenant_id
  sku_name                    = var.sku_name

  soft_delete_retention_days  = var.soft_delete_retention_days
  purge_protection_enabled    = true
  enable_rbac_authorization   = true
  public_network_access_enabled = var.public_network_access_enabled
  enabled_for_deployment      = false
  enabled_for_disk_encryption = false
  enabled_for_template_deployment = false
  tags                        = var.tags

  dynamic "network_acls" {
    for_each = var.network_acls == null ? [] : [var.network_acls]
    content {
      default_action             = network_acls.value.default_action
      bypass                     = network_acls.value.bypass
      ip_rules                   = network_acls.value.ip_rules
      virtual_network_subnet_ids = network_acls.value.subnet_ids
    }
  }
}

# Optional private endpoint
resource "azurerm_private_endpoint" "kv" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "pe-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "kv"
    is_manual_connection           = false
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
  }
  tags = var.tags
}

# Diagnostic settings
resource "azurerm_monitor_diagnostic_setting" "kv" {
  name                       = "ds-${var.name}"
  target_resource_id         = azurerm_key_vault.this.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}