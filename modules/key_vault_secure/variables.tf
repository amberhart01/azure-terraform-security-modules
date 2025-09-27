variable "name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tenant_id" { type = string }
variable "sku_name" { type = string default = "standard" }
variable "soft_delete_retention_days" { type = number default = 90 }
variable "public_network_access_enabled" { type = bool default = false }
variable "network_acls" {
  type = object({
    default_action = string
    bypass         = string
    ip_rules       = list(string)
    subnet_ids     = list(string)
  })
  default = null
}
variable "enable_private_endpoint" { type = bool default = true }
variable "private_endpoint_subnet_id" { type = string default = null }
variable "log_analytics_workspace_id" { type = string }
variable "tags" { type = map(string) default = {} }