output "provider_arn" {
  description = "ARN of the OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "role_arns" {
  description = "Map role name to role ARN, source of BACKEND_BUILD_ROLE_ARN, FRONTEND_BUILD_ROLE_ARN and DEPLOY_ROLE_ARN"
  value       = { for name, role in aws_iam_role.this : name => role.arn }
}

output "subjects" {
  description = "Map role name to the exact sub claim of its rendered trust policy, the source of BACKEND_BUILD_OIDC_SUB, FRONTEND_BUILD_OIDC_SUB and OIDC_EXPECTED_SUB, so GitHub variables cannot drift from STS"
  value = {
    for name, doc in local.trust : name => jsondecode(doc).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"]
  }
}
