output "cloudwatch_logging_role_arn" {
  description = "The ARN of the IAM Role for CloudWatch logging"
  value       = aws_iam_role.cloudwatch_logging_role.arn
}

output "cloudwatch_logging_role_name" {
  description = "The name of the IAM Role for CloudWatch logging"
  value       = aws_iam_role.cloudwatch_logging_role.name
}

output "cloudwatch_logging_policy_arn" {
  description = "The ARN of the IAM Policy for CloudWatch logging"
  value       = aws_iam_policy.cloudwatch_logging_policy.arn
}

output "cloudwatch_logging_policy_name" {
  description = "The name of the IAM Policy for CloudWatch logging"
  value       = aws_iam_policy.cloudwatch_logging_policy.name
}

output "amazon_apigateway_push_policy_attachment_status" {
  description = "Status of the AmazonAPIGatewayPushToCloudWatchLogs policy attachment"
  value       = aws_iam_role_policy_attachment.AmazonAPIGatewayPushToCloudWatchLogs.id
}
