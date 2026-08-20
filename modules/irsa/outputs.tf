output "role_arn" {
  description = "ARN of the IRSA role. Annotate the service account with eks.amazonaws.com/role-arn set to this."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IRSA role."
  value       = aws_iam_role.this.name
}

output "service_account_annotation" {
  description = "Ready to paste service account annotation."
  value = {
    "eks.amazonaws.com/role-arn" = aws_iam_role.this.arn
  }
}
