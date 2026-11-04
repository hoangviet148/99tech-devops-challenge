locals {
  group_name     = "backend-${var.environment}"
  log_group_name = "/backend/${var.environment}"
  templates = {
    for doc in ["trust/backend-instance", "permissions/backend-instance", "trust/backend-codedeploy", "permissions/backend-codedeploy"] :
    doc => replace(file("${var.policy_dir}/${doc}.json"), "/<([A-Z_]+)>/", "$${$1}")
  }
  policies = { for doc, template in local.templates : doc => templatestring(template, var.policy_vars) }
}

resource "aws_cloudwatch_log_group" "this" {
  name              = local.log_group_name
  retention_in_days = 30
}

resource "aws_iam_role" "instance" {
  name               = "backend-instance"
  assume_role_policy = local.policies["trust/backend-instance"]
}

resource "aws_iam_role_policy" "instance" {
  name   = "permissions"
  role   = aws_iam_role.instance.name
  policy = local.policies["permissions/backend-instance"]
}

resource "aws_iam_instance_profile" "this" {
  name = "backend-instance"
  role = aws_iam_role.instance.name
}

resource "aws_launch_template" "this" {
  name                   = local.group_name
  image_id               = "resolve:ssm:/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.instance.id]
  update_default_version = true
  user_data = base64encode(templatefile("${path.module}/user-data.sh.tftpl", {
    region          = var.region
    artifact_bucket = var.artifact_bucket
    node_tarball    = var.node_tarball
    node_sha256     = var.node_sha256
    allowed_origins = join(",", var.allowed_origins)
    log_group       = local.log_group_name
  }))

  iam_instance_profile {
    arn = aws_iam_instance_profile.this.arn
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      encrypted             = true
      volume_type           = "gp3"
      delete_on_termination = true
    }
  }
}

resource "aws_autoscaling_group" "this" {
  name                      = local.group_name
  min_size                  = var.min_size
  max_size                  = var.max_size
  vpc_zone_identifier       = var.private_subnet_ids
  target_group_arns         = [aws_lb_target_group.this.arn]
  health_check_type         = var.health_check_type
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  instance_refresh {
    strategy = "Rolling"

    preferences {
      min_healthy_percentage = 100
      max_healthy_percentage = 200
      skip_matching          = true
    }
  }

  tag {
    key                 = "Name"
    value               = local.group_name
    propagate_at_launch = true
  }
}
