output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "Public subnet IDs in var.availability_zones order, for the ALB. Known only once the internet route exists, because an internet-facing ALB needs it"
  value       = [for az in var.availability_zones : aws_subnet.public[az].id]
  depends_on  = [aws_internet_gateway.this, aws_route.internet, aws_route_table_association.public]
}

output "private_subnet_ids" {
  description = "Private subnet IDs in var.availability_zones order, for the Auto Scaling group"
  value       = [for az in var.availability_zones : aws_subnet.private[az].id]
}

output "s3_prefix_list_id" {
  description = "Prefix list ID of the S3 gateway endpoint, for the instance egress rule"
  value       = aws_vpc_endpoint.s3.prefix_list_id
}

output "endpoint_security_group_id" {
  description = "Security group of the interface endpoints. The backend module adds the ingress rule from its instances"
  value       = aws_security_group.endpoints.id
}
