# Example: assign at subscription scope
module "policy_sub" {
  source          = "../../modules/azure_policies"
  location        = "eastus"
  subscription_id = "/subscriptions/00000000-0000-0000-0000-000000000000"

  assignments = {
    require-storage-https = {
      display_name         = "Require HTTPS for Storage"
      policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/<policy-id>"
      parameters           = {}
    }
  }
}

# Example: assign at resource group scope
module "policy_rg" {
  source            = "../../modules/azure_policies"
  location          = "eastus"
  resource_group_id = azurerm_resource_group.rg.id

  assignments = {
    kv-public-network-disabled = {
      display_name         = "Key Vault - Public network access disabled"
      policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/<policy-id>"
      parameters           = {}
    }
  }
}
