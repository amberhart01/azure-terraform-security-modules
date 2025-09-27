terraform {
  required_version = ">= 1.6"
  required_providers { azurerm = { source = "hashicorp/azurerm", version = ">= 3.112.0" } }
}
provider "azurerm" { features {} }

resource "azurerm_resource_group" "rg" {
  name     = "rg-sec-mod-demo"
  location = "eastus"
}

# Log Analytics for diagnostics
resource "azurerm_log_analytics_workspace" "law" {
  name                = "law-sec-mod-demo"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

module "kv" {
  source                  = "../../modules/key_vault_secure"
  name                    = "kv-sec-demo-1234"
  location                = azurerm_resource_group.rg.location
  resource_group_name     = azurerm_resource_group.rg.name
  tenant_id               = "${data.azurerm_client_config.current.tenant_id}"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id
  enable_private_endpoint = false
}

data "azurerm_client_config" "current" {}

module "sa" {
  source                      = "../../modules/storage_account_secure"
  name                        = "sasecdemo1234"
  location                    = azurerm_resource_group.rg.location
  resource_group_name         = azurerm_resource_group.rg.name
  log_analytics_workspace_id  = azurerm_log_analytics_workspace.law.id
  network_default_action      = "Deny"
  ip_rules                    = ["YOUR_IP/32"]
  subnet_ids                  = []
}