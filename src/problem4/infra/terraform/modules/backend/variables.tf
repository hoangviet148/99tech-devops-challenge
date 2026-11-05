variable "environment" {
  type        = string
  description = "staging or production. Names the backend-<environment> resources and the log group"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "The environment must be staging or production."
  }
}

variable "region" {
  type        = string
  description = "Region of the fleet, used in the user data and the log group ARN"
}

variable "vpc_id" {
  type        = string
  description = "VPC of the security groups and the target group"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Subnets of the ALB"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Subnets of the Auto Scaling group"
}

variable "endpoint_security_group_id" {
  type        = string
  description = "Security group of the interface endpoints, the only 443 egress besides S3. This module adds its ingress rule from the instances"
}

variable "s3_prefix_list_id" {
  type        = string
  description = "Prefix list of the S3 gateway endpoint"
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate of the API host in var.region, for the HTTPS listener"
}

variable "artifact_bucket" {
  type        = string
  description = "Delivery account artifact bucket. The instances read backend/* only: release bundles and backend/runtime/<node_tarball>"
}

variable "node_tarball" {
  type        = string
  description = "File name of the pinned runtime, node-v<backend/.node-version>-linux-x64.tar.xz, staged at backend/runtime/ in the artifact bucket"
}

variable "node_sha256" {
  type        = string
  description = "SHA-256 of node_tarball from backend/node-sha256.txt"

  validation {
    condition     = can(regex("^[0-9a-f]{64}$", var.node_sha256))
    error_message = "The node_sha256 value must be 64 lowercase hex digits. A null value means backend/node-sha256.txt has no line for node_tarball."
  }
}

variable "allowed_origins" {
  type        = list(string)
  description = "Origins written to ALLOWED_ORIGINS in /etc/backend/backend.env for CORS"
}

variable "instance_type" {
  type        = string
  description = "x86_64 instance type, for example t3.small. The AMI parameter and the Node.js tarball are x86_64"

  validation {
    condition     = can(regex("^[a-z]+[0-9]+[a-z0-9-]*\\.[a-z0-9]+$", var.instance_type)) && !can(regex("^(a1\\.|[a-z]+[0-9]+g)", var.instance_type))
    error_message = "The instance_type must be an x86_64 type such as t3.small. Graviton types such as t4g or m7g cannot run the x86_64 AMI and runtime."
  }
}

variable "min_size" {
  type        = number
  description = "Minimum fleet size, at least 2 (A2, rolling deploys without downtime)"

  validation {
    condition     = var.min_size >= 2
    error_message = "The min_size value must be at least 2, so that a rolling deploy keeps an instance in service."
  }
}

variable "max_size" {
  type        = number
  description = "Maximum fleet size, at least min_size"

  validation {
    condition     = var.max_size >= var.min_size
    error_message = "The max_size value must not be below min_size."
  }
}

variable "health_check_type" {
  type        = string
  description = "EC2 until the first release is deployed, then ELB. With ELB the group replaces every instance that has no release yet"

  validation {
    condition     = contains(["EC2", "ELB"], var.health_check_type)
    error_message = "The health_check_type must be EC2 or ELB."
  }
}

variable "policy_dir" {
  type        = string
  description = "Path of infra/policies, where trust/ and permissions/ hold the documents of backend-instance and backend-codedeploy"
}

variable "policy_vars" {
  type        = map(string)
  description = "Placeholder values of the calling root, used to render the backend-instance and backend-codedeploy documents"
}

variable "alarm_actions" {
  type        = list(string)
  description = "Optional SNS topic ARNs for the two G5 alarms"
  default     = []
}
