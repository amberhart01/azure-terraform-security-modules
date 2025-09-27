variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "dns_prefix" { type = string }

variable "authorized_ip_ranges" {
  type    = list(string)
  default = []
}

variable "enable_private_cluster" {
  type    = bool
  default = true
}

variable "network_plugin" {
  type    = string
  default = "azure"
}

variable "network_policy" {
  type    = string
  default = "azure"
}

variable "admin_group_object_ids" { type = list(string) }

variable "system_node_vm_size" {
  type    = string
  default = "Standard_DS3_v2"
}

variable "system_node_count" {
  type    = number
  default = 1
}

variable "tags" {
  type    = map(string)
  default = {}
}