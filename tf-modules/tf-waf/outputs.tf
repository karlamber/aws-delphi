output "web_acl_id" {
  description = "The ID of the WAF Web ACL"
  value       = aws_wafv2_web_acl.this.id
}

output "web_acl_arn" {
  description = "The ARN of the WAF Web ACL"
  value       = aws_wafv2_web_acl.this.arn
}

output "web_acl_name" {
  description = "The name of the WAF Web ACL"
  value       = aws_wafv2_web_acl.this.name
}

output "web_acl_capacity" {
  description = "The capacity (WCU) of the WAF Web ACL"
  value       = aws_wafv2_web_acl.this.capacity
}

output "log_group_name" {
  description = "The name of the CloudWatch log group for WAF logs"
  value       = aws_cloudwatch_log_group.waf_logs.name
}

output "log_group_arn" {
  description = "The ARN of the CloudWatch log group for WAF logs"
  value       = aws_cloudwatch_log_group.waf_logs.arn
}

output "logging_enabled" {
  description = "Whether WAF logging is currently enabled"
  value       = var.enable_logging
}

output "logging_configuration_id" {
  description = "The ID of the WAF logging configuration resource (null if logging is disabled)"
  value       = var.enable_logging ? aws_wafv2_web_acl_logging_configuration.this[0].id : null
}

output "maintenance_mode_enabled" {
  description = "Whether maintenance mode is enabled (WAF block returns 302 redirect to /maintenance.html; for CloudFront custom error 503→maintenance when origin returns 503)"
  value       = var.maintenance_mode_enabled
}

output "ip_set_arns" {
  description = "Map of custom IP set names to ARNs (for scope_down_statement ip_set_key references)"
  value       = { for k, v in aws_wafv2_ip_set.custom : k => v.arn }
}

