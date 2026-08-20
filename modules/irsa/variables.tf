variable "role_name" {
  description = "Name of the IAM role to create."
  type        = string
}

variable "description" {
  description = "Human readable description for the role."
  type        = string
  default     = "IRSA role managed by terraform-aws-eks-platform"
}

variable "oidc_provider_arn" {
  description = "ARN of the cluster's IAM OIDC provider."
  type        = string
}

variable "oidc_provider_url" {
  description = "OIDC issuer URL without the https:// scheme."
  type        = string
}

variable "namespace" {
  description = "Kubernetes namespace of the service account."
  type        = string
}

variable "service_account_name" {
  description = "Name of the Kubernetes service account allowed to assume this role."
  type        = string
}

variable "managed_policy_arns" {
  description = "AWS managed policy ARNs to attach."
  type        = list(string)
  default     = []
}

variable "inline_policy_json" {
  description = "Optional customer managed policy document to create and attach."
  type        = string
  default     = null
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds."
  type        = number
  default     = 3600
}

variable "tags" {
  description = "Tags applied to the role."
  type        = map(string)
  default     = {}
}
