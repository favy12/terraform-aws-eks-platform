variable "cluster_name" {
  description = "Name of the EKS cluster."
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes minor version for the control plane, for example \"1.30\"."
  type        = string
}

variable "vpc_id" {
  description = "VPC the cluster is deployed into."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for the control plane ENIs and worker nodes."
  type        = list(string)
}

variable "endpoint_public_access" {
  description = "Expose the Kubernetes API endpoint publicly. Keep true only while public_access_cidrs is restrictive."
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "CIDRs allowed to reach the public API endpoint. Defaulting to 0.0.0.0/0 is convenient and wrong for production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enabled_cluster_log_types" {
  description = "Control plane log types to ship to CloudWatch."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
}

variable "control_plane_log_retention_days" {
  description = "Retention for the control plane log group."
  type        = number
  default     = 90
}

variable "kms_key_deletion_window" {
  description = "Waiting period before the secrets KMS key is destroyed."
  type        = number
  default     = 30
}

variable "bootstrap_creator_admin" {
  description = "Grant cluster-admin to the IAM principal that creates the cluster. Useful for bootstrap, worth revoking after."
  type        = bool
  default     = true
}

variable "node_groups" {
  description = "Managed node groups, keyed by name."

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

  validation {
    condition     = alltrue([for ng in var.node_groups : ng.min_size <= ng.desired_size && ng.desired_size <= ng.max_size])
    error_message = "Each node group must satisfy min_size <= desired_size <= max_size."
  }

  validation {
    condition     = alltrue([for ng in var.node_groups : contains(["ON_DEMAND", "SPOT"], ng.capacity_type)])
    error_message = "capacity_type must be either ON_DEMAND or SPOT."
  }
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
