variable "cluster_name" {
  description = "Name of the EKS cluster to install addons into."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider."
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC issuer URL without the https:// scheme."
  type        = string
}

variable "addon_versions" {
  description = "Pinned addon versions. Null lets EKS pick the default for the cluster version, which is fine for dev and not for prod."

  type = object({
    vpc_cni    = optional(string)
    kube_proxy = optional(string)
    coredns    = optional(string)
    ebs_csi    = optional(string)
  })

  default = {}
}

variable "enable_cluster_autoscaler" {
  description = "Create the IRSA role for cluster-autoscaler."
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Create the IRSA role for external-dns."
  type        = bool
  default     = false
}

variable "external_dns_hosted_zone_ids" {
  description = "Route53 hosted zone IDs external-dns may write to."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for id in var.external_dns_hosted_zone_ids : can(regex("^Z[A-Z0-9]+$", id))])
    error_message = "Hosted zone IDs look like Z1234567890ABC, not the domain name."
  }
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
