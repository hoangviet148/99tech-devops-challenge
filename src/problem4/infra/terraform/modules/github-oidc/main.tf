locals {
  templates = {
    for name, r in var.roles : name => {
      trust       = replace(file(r.trust_file), "/<([A-Z_]+)>/", "$${$1}")
      permissions = replace(file(r.permissions_file), "/<([A-Z_]+)>/", "$${$1}")
    }
  }
  trust       = { for name, t in local.templates : name => templatestring(t.trust, var.policy_vars) }
  permissions = { for name, t in local.templates : name => templatestring(t.permissions, var.policy_vars) }
}

resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "this" {
  for_each           = var.roles
  name               = each.key
  assume_role_policy = local.trust[each.key]

  depends_on = [aws_iam_openid_connect_provider.github]
}

resource "aws_iam_role_policy" "this" {
  for_each = var.roles
  name     = "permissions"
  role     = aws_iam_role.this[each.key].name
  policy   = local.permissions[each.key]
}
