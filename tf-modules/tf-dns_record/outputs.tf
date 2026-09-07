output "dns_record_name" {
  description = "The name of the DNS record."
  value       = aws_route53_record.dns_record.name
}

output "dns_record_fqdn" {
  description = "The FQDN of the DNS record."
  value       = aws_route53_record.dns_record.fqdn
}

output "dns_record_type" {
  description = "The type of the DNS record."
  value       = aws_route53_record.dns_record.type
}

output "dns_record_zone_id" {
  description = "The hosted zone ID where the record was created."
  value       = aws_route53_record.dns_record.zone_id
}

output "dns_record_records" {
  description = "The records in the DNS record."
  value       = aws_route53_record.dns_record.records
}

