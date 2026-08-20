data "aws_partition" "current" {}

locals {
  tags = merge(var.tags, {
    "Module" = "addons"
  })

  partition = data.aws_partition.current.partition
}

# ---------------------------------------------------------------------------
# EBS CSI driver
#
# Without this, any PersistentVolumeClaim on a 1.23+ cluster stays Pending
# forever. It is not optional in practice, which is why it is not a flag.
# ---------------------------------------------------------------------------

module "ebs_csi_irsa" {
  source = "../irsa"

  role_name            = "${var.cluster_name}-ebs-csi"
  description          = "EBS CSI driver for ${var.cluster_name}"
  oidc_provider_arn    = var.oidc_provider_arn
  oidc_provider_url    = var.oidc_provider_url
  namespace            = "kube-system"
  service_account_name = "ebs-csi-controller-sa"

  managed_policy_arns = [
    "arn:${local.partition}:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
  ]

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Managed addons
#
# resolve_conflicts_on_update = PRESERVE keeps any field a human or Helm has
# changed in-cluster from being stomped on the next apply.
# ---------------------------------------------------------------------------

resource "aws_eks_addon" "vpc_cni" {
  cluster_name  = var.cluster_name
  addon_name    = "vpc-cni"
  addon_version = var.addon_versions.vpc_cni

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = local.tags
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name  = var.cluster_name
  addon_name    = "kube-proxy"
  addon_version = var.addon_versions.kube_proxy

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = local.tags
}

resource "aws_eks_addon" "coredns" {
  cluster_name  = var.cluster_name
  addon_name    = "coredns"
  addon_version = var.addon_versions.coredns

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = local.tags
}

resource "aws_eks_addon" "ebs_csi" {
  cluster_name             = var.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = var.addon_versions.ebs_csi
  service_account_role_arn = module.ebs_csi_irsa.role_arn

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "PRESERVE"

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Cluster autoscaler
#
# The describe calls have to be unscoped because the autoscaler enumerates
# every ASG before it can work out which ones belong to this cluster. The
# mutating calls are scoped by tag, which is where the actual boundary is.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  statement {
    sid     = "Discovery"
    effect  = "Allow"
    actions = [
      "autoscaling:DescribeAutoScalingGroups",
      "autoscaling:DescribeAutoScalingInstances",
      "autoscaling:DescribeLaunchConfigurations",
      "autoscaling:DescribeScalingActivities",
      "autoscaling:DescribeTags",
      "ec2:DescribeImages",
      "ec2:DescribeInstanceTypes",
      "ec2:DescribeLaunchTemplateVersions",
      "eks:DescribeNodegroup",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "Scale"
    effect  = "Allow"
    actions = [
      "autoscaling:SetDesiredCapacity",
      "autoscaling:TerminateInstanceInAutoScalingGroup",
    ]
    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceTag/k8s.io/cluster-autoscaler/${var.cluster_name}"
      values   = ["owned"]
    }
  }
}

module "cluster_autoscaler_irsa" {
  source = "../irsa"
  count  = var.enable_cluster_autoscaler ? 1 : 0

  role_name            = "${var.cluster_name}-cluster-autoscaler"
  description          = "Cluster autoscaler for ${var.cluster_name}"
  oidc_provider_arn    = var.oidc_provider_arn
  oidc_provider_url    = var.oidc_provider_url
  namespace            = "kube-system"
  service_account_name = "cluster-autoscaler"
  inline_policy_json   = data.aws_iam_policy_document.cluster_autoscaler[0].json

  tags = local.tags
}

# ---------------------------------------------------------------------------
# external-dns
#
# Scoped to the specific hosted zones it is allowed to manage. Granting
# route53:ChangeResourceRecordSets on "*" means a misconfigured annotation can
# rewrite an unrelated production zone.
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "external_dns" {
  count = var.enable_external_dns ? 1 : 0

  statement {
    sid       = "ChangeRecords"
    effect    = "Allow"
    actions   = ["route53:ChangeResourceRecordSets"]
    resources = [for zone_id in var.external_dns_hosted_zone_ids : "arn:${local.partition}:route53:::hostedzone/${zone_id}"]
  }

  statement {
    sid     = "ListZones"
    effect  = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResources",
    ]
    resources = ["*"]
  }
}

module "external_dns_irsa" {
  source = "../irsa"
  count  = var.enable_external_dns ? 1 : 0

  role_name            = "${var.cluster_name}-external-dns"
  description          = "external-dns for ${var.cluster_name}"
  oidc_provider_arn    = var.oidc_provider_arn
  oidc_provider_url    = var.oidc_provider_url
  namespace            = "kube-system"
  service_account_name = "external-dns"
  inline_policy_json   = data.aws_iam_policy_document.external_dns[0].json

  tags = local.tags
}
