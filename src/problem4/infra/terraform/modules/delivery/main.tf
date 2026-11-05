locals {
  buckets = {
    artifact = { name = var.artifact_bucket, retention = "production-current-plus-3-staging-last-3" }
    manifest = { name = var.manifest_bucket, retention = "keep-forever" }
  }
  templates = { for k, f in var.bucket_policy_files : k => replace(file(f), "/<([A-Z_]+)>/", "$${$1}") }
  policies  = { for k, t in local.templates : k => templatestring(t, var.policy_vars) }
}

resource "aws_s3_bucket" "this" {
  for_each = local.buckets
  bucket   = each.value.name
  tags = {
    retention = each.value.retention
  }
}

resource "aws_s3_bucket_versioning" "this" {
  for_each = local.buckets
  bucket   = aws_s3_bucket.this[each.key].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_ownership_controls" "this" {
  for_each = local.buckets
  bucket   = aws_s3_bucket.this[each.key].id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "this" {
  for_each                = local.buckets
  bucket                  = aws_s3_bucket.this[each.key].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#trivy:ignore:AWS-0132 SSE-S3, cross-account readers hold no KMS grant
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  for_each = local.buckets
  bucket   = aws_s3_bucket.this[each.key].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_policy" "this" {
  for_each   = local.buckets
  bucket     = aws_s3_bucket.this[each.key].bucket
  policy     = local.policies[each.key]
  depends_on = [aws_s3_bucket_public_access_block.this]
}
