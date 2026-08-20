output "cluster_name" {
  description = "Name of the EKS cluster."
  value       = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded CA cert for the cluster, needed to build a kubeconfig."
  value       = aws_eks_cluster.this.certificate_authority[0].data
}

output "cluster_version" {
  description = "Kubernetes version running on the control plane."
  value       = aws_eks_cluster.this.version
}

output "cluster_security_group_id" {
  description = "Security group attached to the control plane ENIs."
  value       = aws_security_group.cluster.id
}

output "node_security_group_id" {
  description = "Security group EKS created for managed node communication."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "oidc_provider_arn" {
  description = "ARN of the IAM OIDC provider. Pass to the irsa module to bind roles to service accounts."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "OIDC issuer URL, without the https:// scheme."
  value       = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

output "node_role_arn" {
  description = "IAM role assumed by worker nodes."
  value       = aws_iam_role.node.arn
}

output "kms_key_arn" {
  description = "KMS key encrypting Kubernetes secrets."
  value       = aws_kms_key.eks.arn
}

output "node_groups" {
  description = "Managed node group details keyed by name."
  value = {
    for name, ng in aws_eks_node_group.this : name => {
      arn    = ng.arn
      status = ng.status
    }
  }
}
