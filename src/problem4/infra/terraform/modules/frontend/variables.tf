variable "environment" {
  type        = string
  description = "staging or production. Names the CloudFront resources and selects the DISTRIBUTION_ID_<ENV> key"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "environment must be staging or production."
  }
}

variable "bucket_name" {
  type        = string
  description = "Name of the frontend bucket, the FRONTEND_BUCKET_<ENV> value"
}

variable "domain_name" {
  type        = string
  description = "Frontend host served as the only distribution alias"
}

variable "certificate_arn" {
  type        = string
  description = "ACM certificate of domain_name, in us-east-1 because CloudFront reads certificates from us-east-1 only"

  validation {
    condition     = startswith(var.certificate_arn, "arn:aws:acm:us-east-1:")
    error_message = "certificate_arn must be an ACM certificate in us-east-1, the only region CloudFront reads certificates from."
  }
}

variable "price_class" {
  type        = string
  description = "CloudFront price class"
  default     = "PriceClass_100"
}

variable "bucket_policy_file" {
  type        = string
  description = "Path of infra/policies/buckets/frontend-<environment>-bucket.json, passed by the root"
}

variable "policy_vars" {
  type        = map(string)
  description = "Placeholder values from the root. The module adds DISTRIBUTION_ID_<ENV> itself"
}

variable "content_security_policy" {
  type        = string
  description = "Content-Security-Policy sent with every response, rendered by the root from infra/policies/content-security-policy.txt"
}
