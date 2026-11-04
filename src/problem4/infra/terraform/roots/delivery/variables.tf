variable "region" {
  type        = string
  description = "Region of every resource in this root and the AWS_REGION GitHub variable"

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
  description = "Account IDs of the delivery, staging and production accounts (assumption A4)"

  validation {
    condition     = alltrue([for id in values(var.accounts) : can(regex("^[0-9]{12}$", id))])
    error_message = "Every account ID must be 12 digits."
  }
}

variable "artifact_bucket" {
  type        = string
  description = "Artifact bucket name, the ARTIFACT_BUCKET value"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.artifact_bucket))
    error_message = "artifact_bucket must be a valid S3 bucket name."
  }
}

variable "manifest_bucket" {
  type        = string
  description = "Manifest bucket name, the MANIFEST_BUCKET value"

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
