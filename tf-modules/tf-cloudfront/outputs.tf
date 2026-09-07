output "origin_bucket_name" {
  description = "Name of the S3 bucket used as the origin."
  value       = aws_s3_bucket.origin.bucket
}

output "origin_bucket_arn" {
  description = "ARN of the S3 bucket used as the origin."
  value       = aws_s3_bucket.origin.arn
}

output "origin_bucket_domain_name" {
  description = "Domain name of the S3 bucket used as the origin."
  value       = aws_s3_bucket.origin.bucket_domain_name
}

output "logging_bucket_name" {
  description = "Name of the S3 bucket used for CloudFront logs."
  value       = aws_s3_bucket.logging.bucket
}

output "logging_bucket_arn" {
  description = "ARN of the S3 bucket used for CloudFront logs."
  value       = aws_s3_bucket.logging.arn
}

output "logging_bucket_domain_name" {
  description = "Domain name of the S3 bucket used for CloudFront logs."
  value       = aws_s3_bucket.logging.bucket_domain_name
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution."
  value       = aws_cloudfront_distribution.this.id
}

output "cloudfront_distribution_domain_name" {
  description = "Domain name of the CloudFront distribution."
  value       = aws_cloudfront_distribution.this.domain_name
}

output "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution."
  value       = aws_cloudfront_distribution.this.arn
}

output "cloudfront_oac_id" {
  description = "ID of the CloudFront Origin Access Control for S3."
  value       = aws_cloudfront_origin_access_control.s3_oac.id
}

output "web_acl_arn" {
  description = "ARN of the default WAF Web ACL (if created)."
  value       = var.web_acl_id == null && var.enable_default_waf ? aws_wafv2_web_acl.cloudfront_waf[0].arn : null
}


