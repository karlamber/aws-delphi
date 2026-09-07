output "bucket_id" {
  description = "The ID of the S3 bucket"
  value       = aws_s3_bucket.bucket.id
}

output "bucket_arn" {
  description = "The ARN of the S3 bucket"
  value       = aws_s3_bucket.bucket.arn
}

output "bucket_name" {
  description = "The name of the S3 bucket"
  value       = aws_s3_bucket.bucket.bucket
}

output "versioning_status" {
  description = "The versioning status of the bucket"
  value       = var.versioning_enabled && length(aws_s3_bucket_versioning.versioning) > 0 ? aws_s3_bucket_versioning.versioning[0].versioning_configuration[0].status : "Not Enabled"
}

output "lifecycle_rule" {
  description = "The lifecycle rule applied to the bucket"
  value       = var.lifecycle_rule
}

output "multipart_abort_days_after_initiation" {
  description = "Days after initiation after which incomplete multipart uploads are aborted, or null if disabled"
  value       = var.multipart_abort_days_after_initiation
}

output "read_only_policy_arns" {
  description = "Read-only IAM policy ARN"
  value       = aws_iam_policy.read_only_policy.arn
}

output "full_access_policy_arns" {
  description = "Full-access IAM policy ARN"
  value       = aws_iam_policy.full_access_policy.arn
}

output "bucket_regional_domain_name" {
  description = "Regional domain name for s3 bucket"
  value       = aws_s3_bucket.bucket.bucket_regional_domain_name
}

output "bucket_policy" {
  description = "The bucket policy JSON"
  value       = length(aws_s3_bucket_policy.cross_account_access) > 0 ? aws_s3_bucket_policy.cross_account_access[0].policy : null
}
