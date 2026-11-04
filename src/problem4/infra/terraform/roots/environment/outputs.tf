output "github_environment_variables" {
  description = "Variables of the GitHub environments backend-<environment> and frontend-<environment>, named as the workflows read them through vars"
  value = {
    "backend-${var.environment}" = {
      DEPLOY_ROLE_ARN        = module.github_oidc.role_arns["backend-${var.environment}-deploy"]
      OIDC_EXPECTED_SUB      = module.github_oidc.subjects["backend-${var.environment}-deploy"]
      CODEDEPLOY_APPLICATION = module.backend.codedeploy_application
      CODEDEPLOY_GROUP       = module.backend.codedeploy_deployment_group
      TARGET_GROUP_ARN       = module.backend.target_group_arn
      BASE_URL               = local.api_base_url
    }
    "frontend-${var.environment}" = {
      DEPLOY_ROLE_ARN   = module.github_oidc.role_arns["frontend-${var.environment}-deploy"]
      OIDC_EXPECTED_SUB = module.github_oidc.subjects["frontend-${var.environment}-deploy"]
      FRONTEND_BUCKET   = module.frontend.bucket_name
      DISTRIBUTION_ID   = module.frontend.distribution_id
      BASE_URL          = "https://${var.frontend_domain}"
      BACKEND_URL       = local.api_base_url
    }
  }
}

output "dns_records" {
  description = "Records to create in the DNS zone: the API host as an alias of the ALB, the frontend host pointing at the distribution"
  value = {
    api = {
      name    = trimprefix(local.api_base_url, "https://")
      target  = module.backend.alb_dns_name
      zone_id = module.backend.alb_zone_id
    }
    frontend = {
      name   = var.frontend_domain
      target = module.frontend.distribution_domain_name
    }
  }
}
