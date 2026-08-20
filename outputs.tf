output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = module.eks.cluster_endpoint
}

output "cluster_version" {
  description = "Kubernetes version on the control plane."
  value       = module.eks.cluster_version
}

output "vpc_id" {
  description = "ID of the VPC."
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnets hosting the worker nodes."
  value       = module.network.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnets hosting NAT and internet-facing load balancers."
  value       = module.network.public_subnet_ids
}

output "nat_public_ips" {
  description = "Egress IPs, for allowlisting with third parties."
  value       = module.network.nat_public_ips
}

output "oidc_provider_arn" {
  description = "IAM OIDC provider ARN, for wiring additional IRSA roles."
  value       = module.eks.oidc_provider_arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL without the scheme, for wiring additional IRSA roles."
  value       = module.eks.oidc_provider_url
}

output "irsa_role_arns" {
  description = "IRSA roles created for platform components."
  value = {
    ebs_csi            = module.addons.ebs_csi_role_arn
    cluster_autoscaler = module.addons.cluster_autoscaler_role_arn
    external_dns       = module.addons.external_dns_role_arn
  }
}

output "kubeconfig_command" {
  description = "Command to write a kubeconfig entry for this cluster."
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}
