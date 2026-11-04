output "artifact_bucket" {
  description = "Artifact bucket name"
  value       = aws_s3_bucket.this["artifact"].bucket
}

output "manifest_bucket" {
  description = "Manifest bucket name"
  value       = aws_s3_bucket.this["manifest"].bucket
}

output "bucket_arns" {
  description = "Map artifact and manifest to bucket ARN"
  value       = { for k, b in aws_s3_bucket.this : k => b.arn }
}
