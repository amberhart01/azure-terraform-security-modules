resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix

  sku_tier = "Paid" # Azure Policy add-on

  oidc_issuer_enabled = true
  workload_identity_enabled = true

  identity {
    type = "SystemAssigned"
  }

  api_server_access_profile {
    authorized_ip_ranges = var.authorized_ip_ranges
    enable_private_cluster = var.enable_private_cluster
  }

  azure_policy_enabled = true

  role_based_access_control_enabled = true
  azure_active_directory_role_based_access_control {
    managed = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  network_profile {
    network_plugin = var.network_plugin # "azure" or "kubenet"; prefer azure + CNI for policy
    network_policy = var.network_policy # "azure" or "calico"
  }

  default_node_pool {
    name       = "system"
    vm_size    = var.system_node_vm_size
    node_count = var.system_node_count
    only_critical_addons_enabled = true
  }

  tags = var.tags
}

# (Optional) Defender for Containers / Microsoft Defender plans can be assigned via azure_policies module