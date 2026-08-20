output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "CIDR block of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs, ordered by availability zone."
  value       = [for az in var.availability_zones : aws_subnet.public[az].id]
}

output "private_subnet_ids" {
  description = "Private subnet IDs, ordered by availability zone. EKS nodes live here."
  value       = [for az in var.availability_zones : aws_subnet.private[az].id]
}

output "nat_gateway_ids" {
  description = "NAT gateway IDs keyed by availability zone."
  value       = { for az, ngw in aws_nat_gateway.this : az => ngw.id }
}

output "nat_public_ips" {
  description = "Elastic IPs fronting the NAT gateways. Useful for allowlisting egress with third parties."
  value       = [for eip in aws_eip.nat : eip.public_ip]
}
