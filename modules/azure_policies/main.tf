data "azurerm_client_config" "current" {}

resource "azurerm_policy_assignment" "this" {
  for_each            = var.assignments
  name                = each.key
  display_name        = each.value.display_name
  policy_definition_id = each.value.policy_definition_id
  scope               = var.scope
  location            = var.location
  identity { type = "SystemAssigned" }
  parameters          = jsonencode(each.value.parameters)
}