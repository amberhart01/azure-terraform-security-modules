variable "name" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "account_tier" { type = string default = "Standard" }
variable "account_replication_type" { type = string default = "GRS" }
variable "network_default_action" { type = string default = "Deny" }
variable "ip_rules" { type = list(string) default = [] }
variable "subnet_ids" { type = list(string) default = [] }
variable "shared_access_key_enabled" { type = bool default = false }
variable "cmk_key_vault_key_id" { type = string default = null }
variable "user_assigned_identity_id" { type = string default = null }
variable "log_analytics_workspace_id" { type = string }
variable "tags" { type = map(string) default = {} }