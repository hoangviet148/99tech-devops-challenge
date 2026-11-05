output "github_repository_variables" {
  description = "Repository variables of SOLUTION.md section 9, named as the workflows read them through vars"
  value = {
    AWS_REGION              = var.region
    ARTIFACT_BUCKET         = module.delivery.artifact_bucket
    MANIFEST_BUCKET         = module.delivery.manifest_bucket
    BACKEND_BUILD_ROLE_ARN  = module.github_oidc.role_arns["backend-build"]
    FRONTEND_BUILD_ROLE_ARN = module.github_oidc.role_arns["frontend-build"]
    BACKEND_BUILD_OIDC_SUB  = module.github_oidc.subjects["backend-build"]
    FRONTEND_BUILD_OIDC_SUB = module.github_oidc.subjects["frontend-build"]
  }
}
