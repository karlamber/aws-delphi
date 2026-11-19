output "role_arn" {
  description = "ARN to store in the GitHub Environment variable AWS_ROLE_TO_ASSUME."
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "IAM role name."
  value       = aws_iam_role.this.name
}
