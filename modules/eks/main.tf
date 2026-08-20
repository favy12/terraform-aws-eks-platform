data "aws_partition" "current" {}
data "aws_caller_identity" "current" {}

locals {
  tags = merge(var.tags, {
    "Module" = "eks"
  })

  partition = data.aws_partition.current.partition
}

# ---------------------------------------------------------------------------
# Secrets encryption
#
# EKS encrypts etcd at rest by default, but envelope encryption with a
# customer-managed key is what most compliance reviews actually ask for.
# ---------------------------------------------------------------------------

resource "aws_kms_key" "eks" {
  description             = "Envelope encryption for ${var.cluster_name} Kubernetes secrets"
  deletion_window_in_days = var.kms_key_deletion_window
  enable_key_rotation     = true

  tags = merge(local.tags, {
    Name = "${var.cluster_name}-eks-secrets"
  })
}

resource "aws_kms_alias" "eks" {
  name          = "alias/${var.cluster_name}-eks-secrets"
  target_key_id = aws_kms_key.eks.key_id
}

# ---------------------------------------------------------------------------
# Control plane IAM
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "cluster_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "cluster" {
  for_each = toset([
    "arn:${local.partition}:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:${local.partition}:iam::aws:policy/AmazonEKSVPCResourceController",
  ])

  role       = aws_iam_role.cluster.name
  policy_arn = each.value
}

# ---------------------------------------------------------------------------
# Control plane logging
#
# Created explicitly rather than letting EKS create it, so that retention is
# managed here instead of defaulting to "never expire".
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.control_plane_log_retention_days

  tags = local.tags
}

resource "aws_security_group" "cluster" {
  name        = "${var.cluster_name}-cluster"
  description = "EKS control plane security group for ${var.cluster_name}"
  vpc_id      = var.vpc_id

  tags = merge(local.tags, {
    Name = "${var.cluster_name}-cluster"
  })
}

resource "aws_vpc_security_group_egress_rule" "cluster_all" {
  security_group_id = aws_security_group.cluster.id
  description       = "Allow all outbound from the control plane ENIs"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------------------
# Cluster
# ---------------------------------------------------------------------------

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  enabled_cluster_log_types = var.enabled_cluster_log_types

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    security_group_ids      = [aws_security_group.cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    resources = ["secrets"]
  }

  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = var.bootstrap_creator_admin
  }

  tags = merge(local.tags, {
    Name = var.cluster_name
  })

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_cloudwatch_log_group.cluster,
  ]
}

# ---------------------------------------------------------------------------
# IRSA
#
# The OIDC provider is what lets a Kubernetes service account assume an IAM
# role directly, so no pod ever needs static credentials or the node role.
# ---------------------------------------------------------------------------

data "tls_certificate" "oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Node group IAM
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "node_assume" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "node" {
  name               = "${var.cluster_name}-node"
  assume_role_policy = data.aws_iam_policy_document.node_assume.json

  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:${local.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:${local.partition}:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:${local.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    # SSM instead of SSH keys: no bastion, no open port 22, full session audit.
    "arn:${local.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ])

  role       = aws_iam_role.node.name
  policy_arn = each.value
}

# ---------------------------------------------------------------------------
# Managed node groups
# ---------------------------------------------------------------------------

resource "aws_eks_node_group" "this" {
  for_each = var.node_groups

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = each.key
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.private_subnet_ids

  instance_types = each.value.instance_types
  capacity_type  = each.value.capacity_type
  disk_size      = each.value.disk_size

  scaling_config {
    desired_size = each.value.desired_size
    min_size     = each.value.min_size
    max_size     = each.value.max_size
  }

  update_config {
    max_unavailable_percentage = each.value.max_unavailable_percentage
  }

  labels = each.value.labels

  dynamic "taint" {
    for_each = each.value.taints

    content {
      key    = taint.value.key
      value  = taint.value.value
      effect = taint.value.effect
    }
  }

  tags = merge(local.tags, {
    Name = "${var.cluster_name}-${each.key}"
  })

  # desired_size drifts once cluster-autoscaler starts doing its job; if
  # Terraform keeps resetting it, every apply becomes a scale-down event.
  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }

  depends_on = [aws_iam_role_policy_attachment.node]
}
