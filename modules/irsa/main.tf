# ---------------------------------------------------------------------------
# IAM Roles for Service Accounts
#
# Binds one IAM role to one Kubernetes service account through the cluster's
# OIDC provider. The sub condition is what stops any other service account in
# the cluster from assuming this role, so it is pinned to an exact
# namespace/name rather than a wildcard.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider_url}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "this" {
  name                 = var.role_name
  description          = var.description
  assume_role_policy   = data.aws_iam_policy_document.assume.json
  max_session_duration = var.max_session_duration

  tags = merge(var.tags, {
    "Module"                 = "irsa"
    "ServiceAccount"         = "${var.namespace}/${var.service_account_name}"
    "kubernetes.io/rolename" = var.role_name
  })
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = toset(var.managed_policy_arns)

  role       = aws_iam_role.this.name
  policy_arn = each.value
}

resource "aws_iam_policy" "inline" {
  count = var.inline_policy_json == null ? 0 : 1

  name        = "${var.role_name}-policy"
  description = "Inline permissions for ${var.namespace}/${var.service_account_name}"
  policy      = var.inline_policy_json

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "inline" {
  count = var.inline_policy_json == null ? 0 : 1

  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.inline[0].arn
}
