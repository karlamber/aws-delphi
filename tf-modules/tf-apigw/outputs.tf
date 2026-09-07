output "api_id" {
  description = "Identifier of the HTTP API."
  value       = aws_apigatewayv2_api.this.id
}

output "api_arn" {
  description = "ARN of the HTTP API."
  value       = aws_apigatewayv2_api.this.arn
}

output "api_endpoint" {
  description = "Invoke URL for the API (default stage; no stage prefix in path). Append paths such as /api/... for Pluto."
  value       = aws_apigatewayv2_api.this.api_endpoint
}

output "execution_arn" {
  description = "Execution ARN prefix for this API (useful for IAM or debugging)."
  value       = aws_apigatewayv2_api.this.execution_arn
}

output "lambda_permission_statement_id" {
  description = "Statement ID of the Lambda permission granting invoke from this API."
  value       = aws_lambda_permission.apigw_invoke.statement_id
}

output "jwt_authorizer_id" {
  description = "ID of the JWT authorizer attached to this API, or null when no authorizer is configured."
  value       = length(aws_apigatewayv2_authorizer.jwt) > 0 ? aws_apigatewayv2_authorizer.jwt[0].id : null
}
