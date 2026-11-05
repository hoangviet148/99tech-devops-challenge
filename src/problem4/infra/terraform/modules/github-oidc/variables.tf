variable "roles" {
  type = map(object({
    trust_file       = string
    permissions_file = string
  }))
  description = "IAM role name to its trust and permissions documents"

  validation {
    condition = alltrue([
      for name, r in var.roles : endswith(r.trust_file, "/trust/${name}.json") && endswith(r.permissions_file, "/permissions/${name}.json")
    ])
    error_message = "Each role must load trust/<name>.json and permissions/<name>.json of its own name."
  }
}

variable "policy_vars" {
  type        = map(string)
  description = "Placeholder values of the calling root. The environment root merges DISTRIBUTION_ID_<ENV> from the frontend module"
}
