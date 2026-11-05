variable "region" {
  type        = string
  description = "Region of the network, the backend fleet and the frontend bucket"

  validation {
    condition     = can(regex("^[a-z]{2}(-[a-z]+)+-[0-9]$", var.region))
    error_message = "region must be an AWS region name such as ap-southeast-1."
  }
}

variable "accounts" {
  type = object({
    delivery   = string
    staging    = string
    production = string
  })
  description = "Account IDs of the delivery, staging and production accounts (assumption A4). This root targets accounts[environment]"

  validation {
    condition     = alltrue([for id in values(var.accounts) : can(regex("^[0-9]{12}$", id))])
    error_message = "Every account ID must be 12 digits."
  }
}

variable "artifact_bucket" {
  type        = string
  description = "Artifact bucket of the delivery account, read by the instances and the deploy roles"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.artifact_bucket))
    error_message = "artifact_bucket must be a valid S3 bucket name."
  }
}

variable "manifest_bucket" {
  type        = string
  description = "Manifest bucket of the delivery account, where the deploy roles write their records"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.manifest_bucket))
    error_message = "manifest_bucket must be a valid S3 bucket name."
  }
}

variable "github" {
  type = object({
    owner    = string
    owner_id = string
    repo     = string
    repo_id  = string
  })
  description = "Repository owner and name with their immutable numeric IDs, the OWNER, OWNER_ID, REPO and REPO_ID values of the OIDC subjects"

  validation {
    condition     = can(regex("^[0-9]+$", var.github.owner_id)) && can(regex("^[0-9]+$", var.github.repo_id))
    error_message = "github.owner_id and github.repo_id must be the numeric IDs GitHub puts in the OIDC subject."
  }
}

variable "offline" {
  type        = bool
  default     = false
  description = "Configure the provider with mock credentials and no AWS call, for the offline plan of scripts/terraform-check.sh only"
}

variable "environment" {
  type        = string
  description = "staging or production. Selects the account, the policy documents and the resource names"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be staging or production."
  }
}

variable "vpc_cidr" {
  type        = string
  description = "IPv4 CIDR of the environment VPC, from /16 to /23. A /16 gives /20 subnets"
}

variable "availability_zones" {
  type        = list(string)
  description = "AZ names of the public and private subnets in var.region, at least two (assumption A2)"

  validation {
    condition     = alltrue([for az in var.availability_zones : can(regex("^${var.region}[a-h]$", az))])
    error_message = "Every availability zone must belong to var.region, such as ap-southeast-1a for ap-southeast-1."
  }
}

variable "fleet" {
  type = object({
    instance_type = string
    min_size      = number
    max_size      = number
  })
  description = "x86_64 instance type and size limits of the backend Auto Scaling group"
}

variable "alb_certificate_arn" {
  type        = string
  description = "ACM certificate of the API host in var.region, for the HTTPS listener"

  validation {
    condition     = startswith(var.alb_certificate_arn, "arn:aws:acm:${var.region}:")
    error_message = "alb_certificate_arn must be an ACM certificate in var.region."
  }
}

variable "cloudfront_certificate_arn" {
  type        = string
  description = "ACM certificate of the frontend host. CloudFront reads certificates from us-east-1 only"

  validation {
    condition     = startswith(var.cloudfront_certificate_arn, "arn:aws:acm:us-east-1:")
    error_message = "cloudfront_certificate_arn must be an ACM certificate in us-east-1."
  }
}

variable "frontend_bucket" {
  type        = string
  description = "Frontend bucket of this environment, the FRONTEND_BUCKET_<ENV> value"
}

variable "frontend_domain" {
  type        = string
  description = "Frontend host, the CloudFront alias and the only CORS origin of the API"
}

variable "bootstrap" {
  type        = bool
  default     = false
  description = "true until the first backend release is deployed. The Auto Scaling group then uses EC2 health checks, so it keeps the instances that have no release yet instead of replacing them"
}

variable "alarm_actions" {
  type        = list(string)
  default     = []
  description = "SNS topic ARNs notified by the two G5 alarms"
}
