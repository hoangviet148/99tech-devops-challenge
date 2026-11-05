locals {
  policies = "${path.module}/../../../policies"

  policy_vars = {
    DELIVERY_ACCOUNT_ID   = var.accounts.delivery
    STAGING_ACCOUNT_ID    = var.accounts.staging
    PRODUCTION_ACCOUNT_ID = var.accounts.production
    ARTIFACT_BUCKET       = var.artifact_bucket
    MANIFEST_BUCKET       = var.manifest_bucket
    OWNER                 = var.github.owner
    OWNER_ID              = var.github.owner_id
    REPO                  = var.github.repo
    REPO_ID               = var.github.repo_id
  }

  build_roles = {
    for app in ["backend", "frontend"] : "${app}-build" => {
      trust_file       = "${local.policies}/trust/${app}-build.json"
      permissions_file = "${local.policies}/permissions/${app}-build.json"
    }
  }
}

module "delivery" {
  source = "../../modules/delivery"

  artifact_bucket = var.artifact_bucket
  manifest_bucket = var.manifest_bucket
  bucket_policy_files = {
    artifact = "${local.policies}/buckets/artifact-bucket.json"
    manifest = "${local.policies}/buckets/manifest-bucket.json"
  }
  policy_vars = local.policy_vars
}

module "github_oidc" {
  source = "../../modules/github-oidc"

  roles       = local.build_roles
  policy_vars = local.policy_vars
}
