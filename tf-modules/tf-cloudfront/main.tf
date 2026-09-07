# S3 Origin Bucket
resource "aws_s3_bucket" "origin" {
  bucket        = "s3-${var.app_alias}-${var.env}-${var.region_short}-cf-origin"
  tags = {
    App_Alias = var.app_alias
    Name = "s3-${var.app_alias}-${var.env}-${var.region_short}-cf-origin"
  }
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.origin.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Block public access to the bucket
resource "aws_s3_bucket_public_access_block" "origin" {
  bucket = aws_s3_bucket.origin.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Attach a bucket policy allowing only CloudFront to access the bucket
resource "aws_s3_bucket_policy" "origin" {
  bucket = aws_s3_bucket.origin.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect: "Allow",
        Principal: {
          Service: "cloudfront.amazonaws.com"
        },
        Action: "s3:GetObject",
        Resource: "${aws_s3_bucket.origin.arn}/*",
        Condition: {
          StringEquals: {
            "AWS:SourceArn": aws_cloudfront_distribution.this.arn
          }
        }
      }
    ]
  })
  depends_on = [aws_cloudfront_distribution.this]
}

# Create the CloudFront OAC for S3
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "${aws_s3_bucket.origin.bucket}-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# S3 Logging Bucket
resource "aws_s3_bucket" "logging" {
  bucket        = "s3-${var.app_alias}-${var.env}-${var.region_short}-cf-logging"
  acl           = "private"  # Ensure this is enabled for CloudFront
  tags = {
    App_Alias = var.app_alias
    Name = "s3-${var.app_alias}-${var.env}-${var.region_short}-cf-logging"
  }
  force_destroy = true
}

# Use specified response headers policy
data "aws_cloudfront_response_headers_policy" "security_headers" {
  count = var.response_headers_policy_name != null && var.response_headers_policy_name != "" ? 1 : 0
  name  = var.response_headers_policy_name
}

locals {
  security_headers_policy_id = var.response_headers_policy_name != null && var.response_headers_policy_name != "" ? data.aws_cloudfront_response_headers_policy.security_headers[0].id : null
}

resource "aws_s3_bucket_ownership_controls" "logging" {
  bucket = aws_s3_bucket.logging.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Block public access to the bucket
resource "aws_s3_bucket_public_access_block" "logging" {
  bucket = aws_s3_bucket.logging.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_policy" "logging_policy" {
  bucket = aws_s3_bucket.logging.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid: "AllowCloudFrontLogs",
        Effect: "Allow",
        Principal: {
          Service: "cloudfront.amazonaws.com"
        },
        Action: "s3:PutObject",
        Resource: ["${aws_s3_bucket.logging.arn}","${aws_s3_bucket.logging.arn}/*"],
        Condition: {
          StringEquals: {
            "AWS:SourceAccount": "${var.account_id}"
          },
          StringLike: {
            "AWS:SourceArn": "arn:aws:cloudfront::${var.account_id}:distribution/*"
          }
        }
      }
    ]
  })
}

# Combine the main S3 origin with any additional origins
locals {
  all_origins = merge(
    {
      # Main S3 origin
      (aws_s3_bucket.origin.bucket) = {
        domain_name              = "${aws_s3_bucket.origin.bucket}.s3.amazonaws.com"
        origin_id                = "${var.app_alias}-s3-origin"
        origin_path              = null
        origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
        custom_origin_config = null
      }
    },
    # Map additional origins to have a null origin_access_control_id if not S3
    { for k, v in var.additional_origins : k => merge(v, {
        origin_access_control_id = null
      }) }
  )
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  aliases             = var.cloudfront_aliases
  default_root_object = var.cloudfront_default_root_object
  is_ipv6_enabled     = false
  http_version        = "http2"
  price_class         = "PriceClass_100"
  wait_for_deployment = true
  web_acl_id = var.web_acl_id != null ? var.web_acl_id : (var.enable_default_waf ? aws_wafv2_web_acl.cloudfront_waf[0].arn : null)
  depends_on = [ aws_s3_bucket.logging, aws_s3_bucket.origin ]
  tags = {
    Name = "cloudfront-${var.app_alias}-${var.env}-${var.region_short}-distribution"
    App_Alias = var.app_alias
  }
  logging_config {
    include_cookies = false
    bucket          = aws_s3_bucket.logging.bucket_regional_domain_name
    prefix          = "${var.app_alias}/"
  }

  # Custom error responses
  dynamic "custom_error_response" {
    for_each = var.custom_error_responses
    content {
      error_code            = custom_error_response.value.error_code
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.response_page_path
      error_caching_min_ttl = custom_error_response.value.error_caching_min_ttl
    }
  }

  # Default cache behavior
  default_cache_behavior {
    allowed_methods        = var.default_cache_behavior.allowed_methods
    cached_methods         = var.default_cache_behavior.cached_methods
    cache_policy_id        = var.default_cache_behavior.cache_policy_id
    compress               = var.default_cache_behavior.compress
    default_ttl            = var.default_cache_behavior.default_ttl
    max_ttl                = var.default_cache_behavior.max_ttl
    min_ttl                = var.default_cache_behavior.min_ttl
    target_origin_id       = var.default_cache_behavior.target_origin_id
    viewer_protocol_policy = var.default_cache_behavior.viewer_protocol_policy
    response_headers_policy_id = local.security_headers_policy_id
  }

  # Ordered cache behaviors
  dynamic "ordered_cache_behavior" {
    for_each = var.ordered_cache_behaviors
    content {
      path_pattern             = ordered_cache_behavior.value.path_pattern
      allowed_methods          = ordered_cache_behavior.value.allowed_methods
      cached_methods           = ordered_cache_behavior.value.cached_methods
      compress                 = ordered_cache_behavior.value.compress
      cache_policy_id          = ordered_cache_behavior.value.cache_policy_id
      origin_request_policy_id = ordered_cache_behavior.value.origin_request_policy_id
      viewer_protocol_policy   = ordered_cache_behavior.value.viewer_protocol_policy
      default_ttl              = ordered_cache_behavior.value.default_ttl
      max_ttl                  = ordered_cache_behavior.value.max_ttl
      min_ttl                  = ordered_cache_behavior.value.min_ttl
      target_origin_id         = ordered_cache_behavior.value.target_origin_id
      response_headers_policy_id = local.security_headers_policy_id
    }

  }

  # Origins
  dynamic "origin" {
    for_each = local.all_origins
    content {
      domain_name = origin.value.domain_name
      origin_id   = origin.value.origin_id
      origin_path = origin.value.origin_path

      # If it's the S3 origin, set the OAC
      # If it's an additional origin with custom config
      #   - If custom_origin_config is null, we skip
      origin_access_control_id = origin.value.origin_access_control_id

      dynamic "custom_origin_config" {
        for_each = origin.value.custom_origin_config != null ? [origin.value.custom_origin_config] : []
        content {
          http_port                = custom_origin_config.value.http_port
          https_port               = custom_origin_config.value.https_port
          origin_protocol_policy   = custom_origin_config.value.origin_protocol_policy
          origin_read_timeout      = custom_origin_config.value.origin_read_timeout
          origin_keepalive_timeout = custom_origin_config.value.origin_keepalive_timeout
          origin_ssl_protocols     = custom_origin_config.value.origin_ssl_protocols
        }
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = var.geo_restriction.restriction_type
      locations        = var.geo_restriction.locations
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.cloudfront_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
}

# Create AWS WAF Web ACL (only if enabled and no external web_acl_id provided)
resource "aws_wafv2_web_acl" "cloudfront_waf" {
  count       = var.web_acl_id == null && var.enable_default_waf ? 1 : 0
  name        = "cloudfront-${var.app_alias}-${var.env}-${var.region_short}-waf"
  description = "WAF ACL with protections for dynamic applications and APIs"
  tags = {
    Name      = "cloudfront-${var.app_alias}-${var.env}-${var.region_short}-waf"
    App_Alias = var.app_alias
  }
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
    metric_name                = "cloudfront-waf-acl-metrics"
  }

  # Rule 1: AWS Managed Rules - Common protections
  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
        rule_action_override {
          name = "SizeRestrictions_BODY"
          action_to_use {
            allow {}
          }
        }
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "AWSManagedRulesCommonRuleSet"
    }
  }

  # Additional protections for dynamic applications and APIs
  rule {
    name     = "AWSManagedRulesKnownBadInputsRuleSet"
    priority = 2

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "AWSManagedRulesKnownBadInputsRuleSet"
    }
  }

  # AWS Managed Rules for SQL Injection protection
  rule {
    name     = "AWSManagedRulesSQLiRuleSet"
    priority = 3

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      sampled_requests_enabled   = true
      metric_name                = "AWSManagedRulesSQLiRuleSet"
    }
  }
}
