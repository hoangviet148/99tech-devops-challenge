locals {
  env        = upper(var.environment)
  account_id = var.accounts[var.environment]
  policies   = "${path.module}/../../../policies"
  app_dir    = "${path.module}/../../../.."

  node_tarball = "node-v${trimspace(file("${local.app_dir}/backend/.node-version"))}-linux-x64.tar.xz"
  node_sha256 = one([
    for line in split("\n", file("${local.app_dir}/backend/node-sha256.txt")) : split(" ", line)[0]
    if endswith(line, " ${local.node_tarball}")
  ])
  api_base_url            = jsondecode(file("${local.app_dir}/frontend/config/${var.environment}.json")).apiBaseUrl
  csp_template            = replace(trimspace(file("${local.policies}/content-security-policy.txt")), "/<([A-Z_]+)>/", "$${$1}")
  content_security_policy = templatestring(local.csp_template, { API_ORIGIN = regex("^https://[^/]+", local.api_base_url) })

  policy_vars = {
    REGION                         = var.region
    ACCOUNT_ID                     = local.account_id
    ENVIRONMENT                    = var.environment
    "${local.env}_ACCOUNT_ID"      = local.account_id
    ARTIFACT_BUCKET                = var.artifact_bucket
    MANIFEST_BUCKET                = var.manifest_bucket
    "FRONTEND_BUCKET_${local.env}" = var.frontend_bucket
    OWNER                          = var.github.owner
    OWNER_ID                       = var.github.owner_id
    REPO                           = var.github.repo
    REPO_ID                        = var.github.repo_id
  }

  deploy_roles = {
    for app in ["backend", "frontend"] : "${app}-${var.environment}-deploy" => {
      trust_file       = "${local.policies}/trust/${app}-${var.environment}-deploy.json"
      permissions_file = "${local.policies}/permissions/${app}-${var.environment}-deploy.json"
    }
  }
}

module "network" {
  source = "../../modules/network"

  name               = var.environment
  region             = var.region
  cidr_block         = var.vpc_cidr
  availability_zones = var.availability_zones
  policy_dir         = local.policies
  policy_vars        = local.policy_vars
}

module "backend" {
  source = "../../modules/backend"

  environment                = var.environment
  region                     = var.region
  vpc_id                     = module.network.vpc_id
  public_subnet_ids          = module.network.public_subnet_ids
  private_subnet_ids         = module.network.private_subnet_ids
  endpoint_security_group_id = module.network.endpoint_security_group_id
  s3_prefix_list_id          = module.network.s3_prefix_list_id
  certificate_arn            = var.alb_certificate_arn
  artifact_bucket            = var.artifact_bucket
  node_tarball               = local.node_tarball
  node_sha256                = local.node_sha256
  allowed_origins            = ["https://${var.frontend_domain}"]
  instance_type              = var.fleet.instance_type
  min_size                   = var.fleet.min_size
  max_size                   = var.fleet.max_size
  health_check_type          = var.bootstrap ? "EC2" : "ELB"
  alarm_actions              = var.alarm_actions
  policy_dir                 = local.policies
  policy_vars                = local.policy_vars
}

module "frontend" {
  source = "../../modules/frontend"

  environment             = var.environment
  bucket_name             = var.frontend_bucket
  domain_name             = var.frontend_domain
  certificate_arn         = var.cloudfront_certificate_arn
  bucket_policy_file      = "${local.policies}/buckets/frontend-${var.environment}-bucket.json"
  policy_vars             = local.policy_vars
  content_security_policy = local.content_security_policy
}

module "github_oidc" {
  source = "../../modules/github-oidc"

  roles = local.deploy_roles
  policy_vars = merge(local.policy_vars, {
    "DISTRIBUTION_ID_${local.env}" = module.frontend.distribution_id
  })
}
