variable "name" {
  description = "Name of the WAF Web ACL"
  type        = string
}

variable "description" {
  description = "Description of the WAF Web ACL"
  type        = string
  default     = null
}

variable "scope" {
  description = "Scope of the WAF Web ACL. Must be CLOUDFRONT or REGIONAL"
  type        = string
  validation {
    condition     = contains(["CLOUDFRONT", "REGIONAL"], var.scope)
    error_message = "Scope must be either CLOUDFRONT or REGIONAL"
  }
}

variable "resource_type" {
  description = "Type of resource this WAF is protecting (e.g., CloudFront, ALB)"
  type        = string
  default     = "CloudFront"
}

variable "default_action" {
  description = "Default action for requests that don't match any rules. Must be 'allow' or 'block'"
  type        = string
  default     = "allow"
  validation {
    condition     = contains(["allow", "block"], var.default_action)
    error_message = "Default action must be either 'allow' or 'block'"
  }
}

variable "rules" {
  description = "List of WAF managed rule group rules to apply"
  type = list(object({
    name            = string
    priority        = number
    rule_name       = string
    vendor_name     = optional(string, "AWS")
    override_action = optional(string, "none") # none, count
    # excluded_rules  = optional(list(string), [])  # Not supported by Terraform AWS provider
    rule_action_overrides = optional(map(object({
      action = string # allow, block, count
    })), {})
    scope_down_statement = optional(object({
      type = string # and, not, or
      # For and_statement and or_statement
      statements = optional(list(object({
        type = optional(string) # byte_match, and, ip_set
        # For ip_set — key into var.ip_sets
        ip_set_key = optional(string)
        # For byte_match
        search_string       = optional(string)
        positional_constraint = optional(string) # EXACTLY, STARTS_WITH, ENDS_WITH, CONTAINS, CONTAINS_WORD
        field_to_match_type = optional(string) # uri_path, method, query_string, body
        text_transformations = optional(list(object({
          priority = number
          type     = string # NONE, COMPRESS_WHITE_SPACE, HTML_ENTITY_DECODE, LOWERCASE, CMD_LINE, URL_DECODE
        })), [])
        # For nested AND statement (used in OR)
        statements = optional(list(object({
          type                = string # byte_match, ip_set
          ip_set_key          = optional(string)
          search_string       = optional(string)
          positional_constraint = optional(string) # EXACTLY, STARTS_WITH, ENDS_WITH, CONTAINS, CONTAINS_WORD
          field_to_match_type = optional(string) # uri_path, method, query_string, body
          text_transformations = optional(list(object({
            priority = number
            type     = string # NONE, COMPRESS_WHITE_SPACE, HTML_ENTITY_DECODE, LOWERCASE, CMD_LINE, URL_DECODE
          })), [])
        })), [])
      })), [])
      # For not_statement - can be a single statement or nested AND/OR
      statement = optional(object({
        type = optional(string) # byte_match, and, or, ip_set
        # For ip_set — key into var.ip_sets
        ip_set_key = optional(string)
        # For byte_match (simple case)
        search_string       = optional(string)
        positional_constraint = optional(string) # EXACTLY, STARTS_WITH, ENDS_WITH, CONTAINS, CONTAINS_WORD
        field_to_match_type = optional(string) # uri_path, method, query_string, body
        text_transformations = optional(list(object({
          priority = number
          type     = string # NONE, COMPRESS_WHITE_SPACE, HTML_ENTITY_DECODE, LOWERCASE, CMD_LINE, URL_DECODE
        })), [])
        # For nested AND statement
        statements = optional(list(object({
          type                = string # byte_match, ip_set
          ip_set_key          = optional(string)
          search_string       = optional(string)
          positional_constraint = optional(string) # EXACTLY, STARTS_WITH, ENDS_WITH, CONTAINS, CONTAINS_WORD
          field_to_match_type = optional(string) # uri_path, method, query_string, body
          text_transformations = optional(list(object({
            priority = number
            type     = string # NONE, COMPRESS_WHITE_SPACE, HTML_ENTITY_DECODE, LOWERCASE, CMD_LINE, URL_DECODE
          })), [])
        })), [])
      }))
    }))
    visibility_config = optional(object({
      cloudwatch_metrics_enabled = optional(bool, true)
      sampled_requests_enabled   = optional(bool, true)
      metric_name                = optional(string)
    }), {})
  }))
  default = []
}

variable "visibility_config" {
  description = "Visibility configuration for the WAF Web ACL"
  type = object({
    cloudwatch_metrics_enabled = bool
    sampled_requests_enabled   = bool
    metric_name                = string
  })
  default = {
    cloudwatch_metrics_enabled = true
    sampled_requests_enabled   = true
    metric_name                = "waf-acl-metrics"
  }
}

variable "app_alias" {
  description = "Alias for application specific resources"
  type        = string
  default     = null
}

variable "tags" {
  description = "Additional tags to apply to the WAF Web ACL"
  type        = map(string)
  default     = {}
}

variable "enable_logging" {
  description = "Enable WAF logging to CloudWatch Logs. Defaults to false for cost optimization. Enable when troubleshooting is needed."
  type        = bool
  default     = false
}

variable "log_group_name" {
  description = "Name of the CloudWatch log group for WAF logs. If not provided, will default to aws-waf-logs-{var.name}. For CLOUDFRONT scope, log group must be in us-east-1 region."
  type        = string
  default     = null
}

variable "log_retention_in_days" {
  description = "Number of days to retain logs in CloudWatch Log Group. Set to 0 for indefinite retention (not recommended for cost reasons)."
  type        = number
  default     = 30
}
# -----------------------------------------------------------------------------
# Maintenance mode (planned deployments / outages)
# When enabled, the Web ACL blocks all traffic except from IPs in maintenance_allowed_ips.
# Set default_action to 'block' and add a high-priority rule to allow those IPs.
# -----------------------------------------------------------------------------
variable "maintenance_mode_enabled" {
  description = "When true, block all traffic except from maintenance_allowed_ips (devops/testing). Used for planned deployments."
  type        = bool
  default     = false
}

variable "maintenance_allowed_ips" {
  description = "List of IPv4 CIDR blocks allowed when maintenance_mode_enabled is true (e.g. [\"1.2.3.4/32\", \"10.0.0.0/8\"])."
  type        = list(string)
  default     = []
}

variable "ip_sets" {
  description = <<-EOT
    Named IP sets for use in managed-rule scope_down_statement (type = "ip_set", ip_set_key = "<name>").
    Example: exclude a client from AWSManagedRulesAnonymousIpList while keeping HostingProviderIPList
    blocking for everyone else:
      ip_sets = { anonymous-ip-exclusions = { addresses = ["1.2.3.4/32"] } }
      scope_down_statement = { type = "not", statement = { type = "ip_set", ip_set_key = "anonymous-ip-exclusions" } }
  EOT
  type = map(object({
    addresses          = list(string)
    ip_address_version = optional(string, "IPV4")
    description        = optional(string)
  }))
  default = {}
}

