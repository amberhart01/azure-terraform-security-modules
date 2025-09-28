variable "location" { type = string }

variable "subscription_id" {
  type    = string
  default = null
}

variable "resource_group_id" {
  type    = string
  default = null
}

variable "assignments" {
  description = "Map of policy assignments to create at the chosen scope."
  type = map(object({
    display_name         = string
    policy_definition_id = string
    parameters           = map(any)
  }))
}
