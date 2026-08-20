terraform {
  required_version = ">= 1.5.0"

  # Remote state with native S3 locking (Terraform 1.10+). On older versions,
  # swap use_lockfile for a dynamodb_table.
  backend "s3" {
    bucket       = "REPLACE-ME-tfstate"
    key          = "eks-platform/dev/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}

module "platform" {
  source = "../../"

  name        = "platform"
  environment = "dev"
  region      = "eu-central-1"

  vpc_cidr           = "10.10.0.0/16"
  availability_zones = ["eu-central-1a", "eu-central-1b", "eu-central-1c"]

  # Dev tradeoffs: one NAT gateway instead of three saves roughly $64/month,
  # and losing egress in one AZ overnight costs nothing here.
  single_nat_gateway = true
  enable_flow_logs   = false

  kubernetes_version = "1.30"

  node_groups = {
    general = {
      instance_types = ["t3.large"]
      capacity_type  = "SPOT"
      desired_size   = 2
      min_size       = 1
      max_size       = 4

      labels = {
        workload = "general"
      }
    }
  }

  enable_cluster_autoscaler = true

  tags = {
    Owner      = "platform-team"
    CostCenter = "engineering"
  }
}

output "cluster_name" {
  value = module.platform.cluster_name
}

output "kubeconfig_command" {
  value = module.platform.kubeconfig_command
}
