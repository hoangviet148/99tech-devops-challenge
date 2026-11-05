locals {
  zone_index    = { for az in var.availability_zones : az => index(["a", "b", "c", "d", "e", "f", "g", "h"], substr(az, length(az) - 1, 1)) }
  public_cidrs  = { for az, i in local.zone_index : az => cidrsubnet(var.cidr_block, 4, i) }
  private_cidrs = { for az, i in local.zone_index : az => cidrsubnet(var.cidr_block, 4, i + 8) }

  interface_services = toset(["ssm", "ssmmessages", "codedeploy", "codedeploy-commands-secure", "logs"])
  endpoint_templates = {
    for service in ["s3", "logs", "ssm"] : service => replace(file("${var.policy_dir}/endpoints/${service}.json"), "/<([A-Z_]+)>/", "$${$1}")
  }
  endpoint_policies = { for service, template in local.endpoint_templates : service => templatestring(template, var.policy_vars) }
}

resource "aws_vpc" "this" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.name
  }
}

resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = var.name
  }
}

resource "aws_subnet" "public" {
  for_each = local.public_cidrs

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.name}-public-${each.key}"
  }
}

resource "aws_subnet" "private" {
  for_each = local.private_cidrs

  vpc_id            = aws_vpc.this.id
  availability_zone = each.key
  cidr_block        = each.value

  tags = {
    Name = "${var.name}-private-${each.key}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-public"
  }
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.name}-private"
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${var.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  policy            = local.endpoint_policies["s3"]

  tags = {
    Name = "${var.name}-s3"
  }
}

resource "aws_security_group" "endpoints" {
  name        = "${var.name}-endpoints"
  description = "HTTPS from the backend instances to the interface endpoints"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.name}-endpoints"
  }
}

resource "aws_vpc_endpoint" "interface" {
  for_each = local.interface_services

  vpc_id              = aws_vpc.this.id
  service_name        = "com.amazonaws.${var.region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  subnet_ids          = [for az in var.availability_zones : aws_subnet.private[az].id]
  security_group_ids  = [aws_security_group.endpoints.id]
  policy              = lookup(local.endpoint_policies, each.key, null)

  tags = {
    Name = "${var.name}-${each.key}"
  }
}
