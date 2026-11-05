variable "name" {
  type        = string
  description = "Environment name used for Name tags (staging or production)"
}

variable "region" {
  type        = string
  description = "Region used in the endpoint service names com.amazonaws.<region>.<service>"
}

variable "cidr_block" {
  type        = string
  description = "VPC IPv4 CIDR from /16 to /23. Subnets are 4 bits longer, so a /16 gives /20 subnets and a /23 gives the /27 minimum of an ALB subnet"

  validation {
    condition     = can(cidrhost(var.cidr_block, 0)) && can(regex("^[0-9.]+/(1[6-9]|2[0-3])$", var.cidr_block))
    error_message = "The cidr_block must be an IPv4 CIDR from /16 to /23, such as 10.20.0.0/16."
  }
}

variable "availability_zones" {
  type        = list(string)
  description = "2 to 8 distinct AZ names ending in a to h (assumption A2 needs at least 2). The AZ letter picks the subnet slot, so adding, removing or reordering AZs keeps the other subnets"

  validation {
    condition = (
      length(var.availability_zones) >= 2 && length(var.availability_zones) <= 8 &&
      length(distinct(var.availability_zones)) == length(var.availability_zones) &&
      alltrue([for az in var.availability_zones : can(regex("^[a-z]{2}(-[a-z]+)+-[0-9][a-h]$", az))])
    )
    error_message = "The availability_zones list must hold 2 to 8 distinct AZ names that end in a letter from a to h."
  }
}

variable "policy_dir" {
  type        = string
  description = "Path of infra/policies. The S3, logs and ssm endpoints read their policies from endpoints/<service>.json there"
}

variable "policy_vars" {
  type        = map(string)
  description = "Placeholder values of the calling root, used to render the endpoint policies"
}
