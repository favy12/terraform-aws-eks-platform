terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket       = "REPLACE-ME-tfstate"
    key          = "eks-platform/prod/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}

module "platform" {
  source = "../../"

  name        = "platform"
  environment = "prod"
  region      = "eu-central-1"

  vpc_cidr           = "10.20.0.0/16"
  availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]

  # One NAT per AZ: an AZ losing its NAT should not take egress down for
  # workloads running in the other two.
  single_nat_gateway = false
  enable_flow_logs   = true

  kubernetes_version = "1.30"

  # The API endpoint stays public but reachable only from the office and the
  # CI egress ranges. Fully private requires a bastion or VPN, which is the
  # right next step but a different change.
  endpoint_public_access = true
  public_access_cidrs    = [
    "203.0.113.0/24", # office
    "198.51.100.0/24" # CI runners
  ]

  # Addon versions are pinned in prod so an upgrade is a reviewed commit
  # rather than something that happens on the next apply.
  addon_versions = {
    vpc_cni    = "v1.18.3-eksbuild.2"
    kube_proxy = "v1.30.3-eksbuild.5"
    coredns    = "v1.11.3-eksbuild.1"
    ebs_csi    = "v1.35.0-eksbuild.1"
  }

  node_groups = {
    system = {
      instance_types = ["m6i.large"]
      capacity_type  = "ON_DEMAND"
      desired_size   = 3
      min_size       = 3
      max_size       = 6

      labels = {
        workload = "system"
      }

      taints = [{
        key    = "CriticalAddonsOnly"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]
    }

    general = {
      instance_types = ["m6i.xlarge", "m6a.xlarge", "m5.xlarge"]
      capacity_type  = "ON_DEMAND"
      disk_size      = 100
      desired_size   = 3
      min_size       = 3
      max_size       = 12

      labels = {
        workload = "general"
      }
    }

    # Spot for anything that can be interrupted. Multiple instance types
    # across the same size class so a single capacity pool drying up does not
    # strand the node group.
    batch = {
      instance_types = ["c6i.2xlarge", "c6a.2xlarge", "c5.2xlarge"]
      capacity_type  = "SPOT"
      desired_size   = 0
      min_size       = 0
      max_size       = 20

      labels = {
        workload = "batch"
      }

      taints = [{
        key    = "workload"
        value  = "batch"
        effect = "NO_SCHEDULE"
      }]
    }
  }

  enable_cluster_autoscaler = true
  enable_external_dns       = true

  external_dns_hosted_zone_ids = ["Z1234567890ABC"]

  tags = {
    Owner      = "platform-team"
    CostCenter = "engineering"
    Compliance = "in-scope"
  }
}

output "cluster_name" {
  value = module.platform.cluster_name
}

output "cluster_endpoint" {
  value = module.platform.cluster_endpoint
}

output "kubeconfig_command" {
  value = module.platform.kubeconfig_command
}
