# Common Variables
variable "region" {
  description = "The AWS region where resources will be created."
  type        = string
}

variable "account_id" {
  description = "AWS account ID."
  type        = string
}

variable "env" {
  description = "Environment identifier (e.g., dev, prod)."
  type        = string
}

variable "region_short" {
  description = "Shortened version of the AWS Region for naming resources."
}

# Module Specific Variables
# The following variables are required for specific resource values
variable "app_alias" {
  description = "Alias for application specific resources"
  type        = string
  default     = ""
}

variable "cloudfront_aliases" {
  type        = list(string)
  description = "Aliases for the CloudFront distribution."
  default     = []
}

variable "cloudfront_certificate_arn" {
  type        = string
  description = "ACM certificate ARN for the CloudFront distribution."
}

variable "cloudfront_default_root_object" {
  type        = string
  description = "Default root object for CloudFront."
  default     = "index.html"
}

# Additional origins besides the S3 bucket. If none provided, only the S3 bucket origin is set.
variable "additional_origins" {
  type = map(object({
    domain_name              = string
    origin_id                = string
    origin_path              = string
    custom_origin_config = object({
      http_port                = number
      https_port               = number
      origin_keepalive_timeout = number
      origin_protocol_policy   = string
      origin_read_timeout      = number
      origin_ssl_protocols     = list(string)
    })
  }))
  description = "Map of additional CloudFront origins. Key is the origin_id."
  default     = {}
}

variable "default_cache_behavior" {
  type = object({
    allowed_methods        = list(string)
    cached_methods         = list(string)
    cache_policy_id        = string
    compress               = bool
    default_ttl            = optional(number)
    max_ttl                = optional(number)
    min_ttl                = optional(number)
    viewer_protocol_policy = string
    target_origin_id       = string
  })
  description = "Default cache behavior for CloudFront."
}

variable "ordered_cache_behaviors" {
  type = list(object({
    path_pattern             = string
    allowed_methods          = list(string)
    cached_methods           = list(string)
    compress                 = bool
    cache_policy_id          = string
    origin_request_policy_id = string
    viewer_protocol_policy   = string
    default_ttl            = optional(number)
    max_ttl                = optional(number)
    min_ttl                = optional(number)
    target_origin_id         = string
  }))
  description = "List of ordered cache behaviors."
  default = []
}

variable "custom_error_responses" {
  type = list(object({
    error_code            = number
    response_code         = number
    response_page_path    = string
    error_caching_min_ttl = number
  }))
  description = "Custom error responses for the CloudFront distribution."
  default = []
}

variable "geo_restriction" {
  description = "Geo restriction settings for CloudFront"
  type = object({
    restriction_type = string
    locations        = list(string)
  })
  default = {
    restriction_type = "whitelist"
    locations        = ["US"]
  }
}

variable "response_headers_policy_name" {
  description = "Name of the CloudFront response headers policy to use (e.g., 'SecurityHeadersPolicy' for AWS managed, or custom policy name)"
  type        = string
  default     = null
}

variable "web_acl_id" {
  description = "ARN of the WAF Web ACL to associate with the CloudFront distribution. If not provided, a default WAF will be created."
  type        = string
  default     = null
}

variable "enable_default_waf" {
  description = "Whether to create a default WAF Web ACL if web_acl_id is not provided. Set to false if you want to manage WAF separately."
  type        = bool
  default     = true
}
