terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0, < 5.0.0"
    }
  }
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix

  # v4: private cluster flag is top-level
  private_cluster_enabled = var.enable_private_cluster

  # OIDC + WI
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  identity { type = "SystemAssigned" }

  # Only authorized IPs (optional; leave empty list to disable)
  api_server_access_profile {
    authorized_ip_ranges = var.authorized_ip_ranges
  }

  # Built-in policy add-on
  azure_policy_enabled = true

  # RBAC + Entra ID integration (v4: no 'managed' arg)
  role_based_access_control_enabled = true
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled      = true
    admin_group_object_ids  = var.admin_group_object_ids
    # tenant_id optional; uses current if omitted
  }

  # Networking
  network_profile {
    network_plugin = var.network_plugin  # "azure" or "kubenet"
    network_policy = var.network_policy  # "azure" or "calico"
  }

  # System node pool
  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_node_vm_size
    node_count                   = var.system_node_count
    only_critical_addons_enabled = true
  }

  # Strengthen posture
  local_account_disabled = true

  sku_tier = "Premium" # required for some add-ons/policy scenarios

  tags = var.tags
}
