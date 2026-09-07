resource "aws_acm_certificate" "tls_cert" {
  domain_name       = var.domain_name
  validation_method = "DNS"

  tags = {
    Name      = "acm-${var.app_alias}-${var.env}-${var.region_short}-certificate"
    App_Alias = var.app_alias
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Get the hosted zone ID from the Route53 account
data "aws_route53_zone" "validation_zone" {
  provider     = aws.route53
  name         = var.hosted_zone_name
  private_zone = false
}

# Create Route53 validation records in the Route53 account
resource "aws_route53_record" "certificate_validation" {
  provider = aws.route53
  for_each = {
    for dvo in aws_acm_certificate.tls_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.validation_zone.zone_id
}

# Wait for certificate validation to complete
resource "aws_acm_certificate_validation" "tls_cert" {
  certificate_arn         = aws_acm_certificate.tls_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.certificate_validation : record.fqdn]
}
