variable "scope" { type = string }
variable "location" { type = string }
variable "assignments" {
  type = map(object({
    display_name         = string
    policy_definition_id = string
    parameters           = map(any)
  }))
}