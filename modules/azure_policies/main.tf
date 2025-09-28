terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0, < 5.0.0"
    }
  }
}

# Use exactly one of subscription_id or resource_group_id.
# The module will create the right assignment type based on which is provided.

locals {
  at_subscription  = var.subscription_id     != null && var.resource_group_id == null
  at_resourcegroup = var.resource_group_id   != null && var.subscription_id   == null
}

# Guardrail: require exactly one scope
# (terraform validate won't fail on 'precondition', but plan/apply will)
resource "null_resource" "scope_guard" {
  lifecycle {
    precondition {
      condition     = local.at_subscription || local.at_resourcegroup
      error_message = "Provide exactly one of subscription_id or resource_group_id."
    }
  }
}

# Subscription-scope assignments
resource "azurerm_subscription_policy_assignment" "sub" {
  for_each            = local.at_subscription ? var.assignments : {}
  name                = each.key
  display_name        = each.value.display_name
  policy_definition_id = each.value.policy_definition_id
  subscription_id     = var.subscription_id
  location            = var.location
  identity {
    type = "SystemAssigned"
  }
  parameters = jsonencode(each.value.parameters)
}

# Resource Group-scope assignments
resource "azurerm_resource_group_policy_assignment" "rg" {
  for_each            = local.at_resourcegroup ? var.assignments : {}
  name                = each.key
  display_name        = each.value.display_name
  policy_definition_id = each.value.policy_definition_id
  resource_group_id   = var.resource_group_id
  location            = var.location
  identity {
    type = "SystemAssigned"
  }
  parameters = jsonencode(each.value.parameters)
}
