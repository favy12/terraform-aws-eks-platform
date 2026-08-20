variable "name" {
  description = "Name prefix applied to every resource in this module."
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name, used for the kubernetes.io/cluster subnet tags."
  type        = string
}

variable "cidr_block" {
  description = "VPC CIDR block. Must be large enough to carve 2x len(availability_zones) subnets."
  type        = string

  validation {
    condition     = can(cidrhost(var.cidr_block, 0))
    error_message = "cidr_block must be a valid IPv4 CIDR, for example 10.0.0.0/16."
  }
}

variable "availability_zones" {
  description = "AZs to spread subnets across. Three is the practical minimum for a production control plane."
  type        = list(string)

  validation {
    condition     = length(var.availability_zones) >= 2
    error_message = "EKS requires subnets in at least two availability zones."
  }
}

variable "subnet_newbits" {
  description = "Bits to add to the VPC prefix when carving subnets. 4 turns a /16 into /20s."
  type        = number
  default     = 4
}

variable "single_nat_gateway" {
  description = "Route all private egress through one NAT gateway. Cheaper, but a single AZ failure takes out egress."
  type        = bool
  default     = false
}

variable "enable_flow_logs" {
  description = "Ship VPC flow logs to CloudWatch. Only REJECT traffic is captured, to keep ingest cost down."
  type        = bool
  default     = true
}

variable "flow_logs_retention_days" {
  description = "CloudWatch retention for flow logs."
  type        = number
  default     = 30
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}
