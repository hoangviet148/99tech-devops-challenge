output "bucket_name" {
  description = "Frontend bucket name, the FRONTEND_BUCKET GitHub variable"
  value       = aws_s3_bucket.this.bucket
}

output "distribution_id" {
  description = "Distribution ID, the DISTRIBUTION_ID GitHub variable and the DISTRIBUTION_ID_<ENV> value of the frontend deploy role"
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_arn" {
  description = "Distribution ARN"
  value       = aws_cloudfront_distribution.this.arn
}

output "distribution_domain_name" {
  description = "cloudfront.net name, target of the frontend host record"
  value       = aws_cloudfront_distribution.this.domain_name
}
