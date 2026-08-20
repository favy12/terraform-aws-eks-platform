variable "name" {
  description = "Platform name. Combined with environment to form the cluster name."
  type        = string
  default     = "platform"
}

variable "environment" {
  description = "Environment name, for example dev, staging or prod."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of dev, staging, prod."
  }
}

variable "region" {
  description = "AWS region to deploy into."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones to spread the cluster across."
  type        = list(string)
}

variable "single_nat_gateway" {
  description = "Share one NAT gateway across all AZs. Saves money in dev, unacceptable in prod."
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Enable VPC flow logs for rejected traffic."
  type        = bool
  default     = true
}

variable "kubernetes_version" {
  description = "Kubernetes minor version for the control plane."
  type        = string
  default     = "1.30"
}

variable "endpoint_public_access" {
  description = "Expose the Kubernetes API publicly."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs permitted to reach the public API endpoint."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_groups" {
  description = "Managed node groups keyed by name."

  type = map(object({
    instance_types             = list(string)
    capacity_type              = optional(string, "ON_DEMAND")
    disk_size                  = optional(number, 50)
    desired_size               = number
    min_size                   = number
    max_size                   = number
    max_unavailable_percentage = optional(number, 33)
    labels                     = optional(map(string), {})
    taints = optional(list(object({
      key    = string
      value  = optional(string)
      effect = string
    })), [])
  }))
}

variable "addon_versions" {
  description = "Pinned EKS addon versions."

  type = object({
    vpc_cni    = optional(string)
    kube_proxy = optional(string)
    coredns    = optional(string)
    ebs_csi    = optional(string)
  })

  default = {}
}

variable "enable_cluster_autoscaler" {
  description = "Create the cluster-autoscaler IRSA role."
  type        = bool
  default     = true
}

variable "enable_external_dns" {
  description = "Create the external-dns IRSA role."
  type        = bool
  default     = false
}

variable "external_dns_hosted_zone_ids" {
  description = "Route53 hosted zones external-dns may write to."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags applied to every resource."
  type        = map(string)
  default     = {}
}
