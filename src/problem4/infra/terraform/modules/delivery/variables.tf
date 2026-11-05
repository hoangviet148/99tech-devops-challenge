variable "artifact_bucket" {
  type        = string
  description = "Artifact bucket name, the ARTIFACT_BUCKET value"
}

variable "manifest_bucket" {
  type        = string
  description = "Manifest bucket name, the MANIFEST_BUCKET value"
}

variable "bucket_policy_files" {
  type        = object({ artifact = string, manifest = string })
  description = "Paths of infra/policies/buckets/artifact-bucket.json and manifest-bucket.json, passed by the root"
}

variable "policy_vars" {
  type        = map(string)
  description = "Placeholder values of the delivery root"
}
