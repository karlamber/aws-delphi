output "certificate_arn" {
  description = "The ARN of the ACM certificate after DNS validation completes."
  value       = aws_acm_certificate_validation.tls_cert.certificate_arn
}

output "certificate_domain_name" {
  description = "The domain name for the ACM certificate."
  value       = aws_acm_certificate.tls_cert.domain_name
}

output "certificate_validation_method" {
  description = "The validation method for the ACM certificate."
  value       = aws_acm_certificate.tls_cert.validation_method
}

output "validation_records" {
  description = "CNAME record information required for DNS validation."
  value       = aws_acm_certificate.tls_cert.domain_validation_options
}

output "certificate_validation_status" {
  description = "The status of the certificate validation."
  value       = aws_acm_certificate_validation.tls_cert.id
}
