output "std_lambda" {
  description = "ARN of the PD Standard Lambda IAM Policy"
  value       = aws_iam_policy.std_lambda.arn
}

output "policy_name" {
  description = "Name of the PD Standard Lambda IAM Policy"
  value       = aws_iam_policy.std_lambda.name
}


