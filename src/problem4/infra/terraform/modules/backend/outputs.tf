output "alb_dns_name" {
  description = "ALB DNS name, target of the API host record"
  value       = aws_lb.this.dns_name
}

output "alb_zone_id" {
  description = "ALB hosted zone ID, for an alias record"
  value       = aws_lb.this.zone_id
}

output "target_group_arn" {
  description = "Target group ARN, the TARGET_GROUP_ARN GitHub variable"
  value       = aws_lb_target_group.this.arn
}

output "codedeploy_application" {
  description = "CodeDeploy application name (backend), the CODEDEPLOY_APPLICATION GitHub variable"
  value       = aws_codedeploy_app.this.name
}

output "codedeploy_deployment_group" {
  description = "Deployment group name (backend-<environment>), the CODEDEPLOY_GROUP GitHub variable"
  value       = aws_codedeploy_deployment_group.this.deployment_group_name
}

output "instance_role_arn" {
  description = "ARN of backend-instance, the principal named in the artifact bucket policy"
  value       = aws_iam_role.instance.arn
}

output "log_group_name" {
  description = "CloudWatch log group of the fleet"
  value       = aws_cloudwatch_log_group.this.name
}
