output "lambda_function_name" {
  description = "The name of the deployed Lambda function"
  value       = aws_lambda_function.this.function_name
}

output "lambda_function_arn" {
  description = "The ARN of the deployed Lambda function"
  value       = aws_lambda_function.this.arn
}

output "lambda_execution_role_name" {
  description = "The name of the IAM role assigned to the Lambda function"
  value       = aws_iam_role.this.name
}

output "lambda_execution_role_arn" {
  description = "The ARN of the IAM role assigned to the Lambda function"
  value       = aws_iam_role.this.arn
}

output "lambda_log_group" {
  description = "The name of the CloudWatch Log Group for the Lambda function"
  value       = aws_cloudwatch_log_group.lambda_logs.name
}

output "lambda_log_group_arn" {
  description = "The ARN of the CloudWatch Log Group for the Lambda function"
  value       = aws_cloudwatch_log_group.lambda_logs.arn
}

output "lambda_log_retention_days" {
  description = "The retention period in days for the Lambda function logs"
  value       = aws_cloudwatch_log_group.lambda_logs.retention_in_days
}

output "lambda_function_invoke_arn" {
  description = "The ARN to invoke the Lambda function"
  value       = aws_lambda_function.this.invoke_arn
}

output "lambda_function_last_modified" {
  description = "The timestamp of the last update to the Lambda function"
  value       = aws_lambda_function.this.last_modified
}

output "lambda_function_version" {
  description = "The version of the Lambda function"
  value       = aws_lambda_function.this.version
}

output "lambda_runtime" {
  description = "The runtime environment for the Lambda function"
  value       = aws_lambda_function.this.runtime
}

output "lambda_tracing_mode" {
  description = "The active tracing mode for the Lambda function"
  value       = aws_lambda_function.this.tracing_config[0].mode
}

output "custom_policy_arn" {
  description = "ARN of the custom IAM policy (if provisioned)"
  value       = length(aws_iam_policy.custom_managed_policy) > 0 ? aws_iam_policy.custom_managed_policy[0].arn : null
}

output "api_gateway_permission_ids" {
  description = "List of statement IDs for API Gateway permissions added to the Lambda function"
  value = [for perm in aws_lambda_permission.api_gateway_triggers : perm.statement_id]
}

output "lambda_destinations" {
  description = "Map of Lambda destinations with retry attempts"
  value = {
    on_success = length(aws_lambda_function_event_invoke_config.on_success) > 0 ? aws_lambda_function_event_invoke_config.on_success : null
    on_failure = length(aws_lambda_function_event_invoke_config.on_failure) > 0 ? aws_lambda_function_event_invoke_config.on_failure : null
  }
}
