locals {
  cluster_name = "${var.name}-${var.environment}"

  tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "terraform-aws-eks-platform"
    Cluster     = local.cluster_name
  })
}

module "network" {
  source = "./modules/network"

  name               = local.cluster_name
  cluster_name       = local.cluster_name
  cidr_block         = var.vpc_cidr
  availability_zones = var.availability_zones
  single_nat_gateway = var.single_nat_gateway
  enable_flow_logs   = var.enable_flow_logs

  tags = local.tags
}

module "eks" {
  source = "./modules/eks"

  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids

  endpoint_public_access = var.endpoint_public_access
  public_access_cidrs    = var.public_access_cidrs

  node_groups = var.node_groups

  tags = local.tags
}

module "addons" {
  source = "./modules/addons"

  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  oidc_provider_url = module.eks.oidc_provider_url

  addon_versions = var.addon_versions

  enable_cluster_autoscaler    = var.enable_cluster_autoscaler
  enable_external_dns          = var.enable_external_dns
  external_dns_hosted_zone_ids = var.external_dns_hosted_zone_ids

  tags = local.tags

  # Addons need at least one node to schedule onto, otherwise coredns sits
  # Pending and the addon reports DEGRADED.
  depends_on = [module.eks]
}
