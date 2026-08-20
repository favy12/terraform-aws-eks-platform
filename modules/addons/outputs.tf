output "ebs_csi_role_arn" {
  description = "IRSA role used by the EBS CSI controller."
  value       = module.ebs_csi_irsa.role_arn
}

output "cluster_autoscaler_role_arn" {
  description = "IRSA role for cluster-autoscaler, or null when disabled."
  value       = var.enable_cluster_autoscaler ? module.cluster_autoscaler_irsa[0].role_arn : null
}

output "external_dns_role_arn" {
  description = "IRSA role for external-dns, or null when disabled."
  value       = var.enable_external_dns ? module.external_dns_irsa[0].role_arn : null
}

output "installed_addons" {
  description = "Addon names and the versions actually resolved by EKS."
  value = {
    vpc-cni            = aws_eks_addon.vpc_cni.addon_version
    kube-proxy         = aws_eks_addon.kube_proxy.addon_version
    coredns            = aws_eks_addon.coredns.addon_version
    aws-ebs-csi-driver = aws_eks_addon.ebs_csi.addon_version
  }
}
