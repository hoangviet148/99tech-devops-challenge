locals {
  bucket_policy_template = replace(file(var.bucket_policy_file), "/<([A-Z_]+)>/", "$${$1}")
}

resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_ownership_controls" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket                  = aws_s3_bucket.this.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#trivy:ignore:AWS-0132 SSE-S3, no KMS grant for OAC or deploy roles
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  bucket = aws_s3_bucket.this.bucket
  policy = templatestring(local.bucket_policy_template, merge(var.policy_vars, {
    "DISTRIBUTION_ID_${upper(var.environment)}" = aws_cloudfront_distribution.this.id
  }))

  depends_on = [aws_s3_bucket_public_access_block.this]
}
