# -----------------------------------------------------------------------------
# Maintenance mode: IP set for allowlisted IPs (devops/testing) during outages.
# -----------------------------------------------------------------------------
resource "aws_wafv2_ip_set" "maintenance_allowed" {
  count               = length(var.maintenance_allowed_ips) > 0 ? 1 : 0
  name                = "${var.name}-maintenance-allowed-ips"
  description         = "IPs allowed to bypass maintenance mode for devops and testing"
  scope               = var.scope
  ip_address_version  = "IPV4"
  addresses           = var.maintenance_allowed_ips
}

# Named IP sets referenced by managed-rule scope_down_statement (type = "ip_set").
resource "aws_wafv2_ip_set" "custom" {
  for_each = var.ip_sets

  name               = "${var.name}-${each.key}"
  description        = coalesce(each.value.description, "IP set ${each.key} for WAF scope-down")
  scope              = var.scope
  ip_address_version = each.value.ip_address_version
  addresses          = each.value.addresses

  tags = merge(
    {
      Name      = "${var.name}-${each.key}"
      App_Alias = var.app_alias != null ? var.app_alias : ""
    },
    var.tags
  )
}

# AWS WAF Web ACL for CloudFront
# NOTE: Excluded rules are not supported by the Terraform AWS provider
# If your WAF has excluded rules configured manually, they will be preserved
# but cannot be managed via Terraform. You'll need to manage excluded rules
# manually in AWS Console or via AWS CLI/API.
resource "aws_wafv2_web_acl" "this" {
  name        = var.name
  description = var.description != null ? var.description : "WAF ACL for ${var.resource_type}"
  scope       = var.scope

  lifecycle {
    # Excluded rules are not managed by Terraform, so ignore any drift
    # This ensures manually configured excluded rules are preserved
    ignore_changes = [
      # Note: excluded_rules are not in Terraform state, but adding this
      # as a safety measure for any future provider updates
    ]
  }

  # When maintenance mode is on, block by default with 302 redirect to /maintenance.html (CloudFront
  # viewer-response does not run for WAF responses, so redirect must come from WAF). Otherwise use var.default_action.
  default_action {
    dynamic "allow" {
      for_each = (var.maintenance_mode_enabled ? "block" : var.default_action) == "allow" ? [1] : []
      content {}
    }
    dynamic "block" {
      for_each = (var.maintenance_mode_enabled ? "block" : var.default_action) == "block" ? [1] : []
      content {
        dynamic "custom_response" {
          for_each = var.maintenance_mode_enabled ? [1] : []
          content {
            response_code = 302
            response_header {
              name  = "Location"
              value = "/maintenance.html"
            }
          }
        }
      }
    }
  }

  # Maintenance mode: allow /maintenance.html so the page can be served (not blocked with 503).
  # Match path that starts with /maintenance.html (case-insensitive) so variations still allow through.
  dynamic "rule" {
    for_each = var.maintenance_mode_enabled ? [1] : []
    content {
      name     = "maintenance-allow-path"
      priority = 0

      statement {
        byte_match_statement {
          search_string         = "/maintenance.html"
          positional_constraint = "STARTS_WITH"
          field_to_match {
            uri_path {}
          }
          text_transformation {
            priority = 0
            type     = "LOWERCASE"
          }
        }
      }

      action {
        allow {}
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        sampled_requests_enabled   = true
        metric_name                = "MaintenanceAllowPath"
      }
    }
  }

  # Maintenance mode: when on, allow allowlisted IPs (priority 1).
  dynamic "rule" {
    for_each = length(var.maintenance_allowed_ips) > 0 ? [1] : []
    content {
      name     = "maintenance-allowlisted-ips"
      priority = 1

      statement {
        ip_set_reference_statement {
          arn = aws_wafv2_ip_set.maintenance_allowed[0].arn
        }
      }

      action {
        dynamic "allow" {
          for_each = var.maintenance_mode_enabled ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = var.maintenance_mode_enabled ? [] : [1]
          content {}
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        sampled_requests_enabled   = true
        metric_name                = "MaintenanceAllowlistedIPs"
      }
    }
  }

  # Managed rules: shift priority so they come after maintenance rules (0 and 1).
  dynamic "rule" {
    for_each = var.rules
    content {
      name     = rule.value.name
      priority = rule.value.priority + (var.maintenance_mode_enabled ? 1 : 0) + (length(var.maintenance_allowed_ips) > 0 ? 1 : 0)

      statement {
        managed_rule_group_statement {
          name        = rule.value.rule_name
          vendor_name = rule.value.vendor_name

          # Excluded rules
          # NOTE: Terraform AWS provider does not support excluded_rule blocks
          # Excluded rules must be managed manually in AWS Console or via AWS CLI/API
          # Workaround: Use rule_action_overrides to set excluded rules to "count" instead
          # dynamic "excluded_rule" {
          #   for_each = try(rule.value.excluded_rules, [])
          #   content {
          #     name = excluded_rule.value
          #   }
          # }

          # Rule action overrides
          dynamic "rule_action_override" {
            for_each = try(rule.value.rule_action_overrides, {})
            content {
              name = rule_action_override.key
              action_to_use {
                dynamic "allow" {
                  for_each = rule_action_override.value.action == "allow" ? [1] : []
                  content {}
                }
                dynamic "block" {
                  for_each = rule_action_override.value.action == "block" ? [1] : []
                  content {}
                }
                dynamic "count" {
                  for_each = rule_action_override.value.action == "count" ? [1] : []
                  content {}
                }
              }
            }
          }

          # Scope down statement
          dynamic "scope_down_statement" {
            for_each = try(rule.value.scope_down_statement, null) != null ? [rule.value.scope_down_statement] : []
            content {
              # AndStatement
              dynamic "and_statement" {
                for_each = try(scope_down_statement.value.type, null) == "and" ? [scope_down_statement.value] : []
                content {
                  dynamic "statement" {
                    for_each = try(and_statement.value.statements, [])
                    content {
                      # Support OR statements nested in AND
                      # NOTE: The Terraform AWS provider does not support and_statement nested
                      # within or_statement. Use byte_match statements directly within or_statement instead.
                      dynamic "or_statement" {
                        for_each = try(statement.value.type, null) == "or" ? [statement.value] : []
                        content {
                          dynamic "statement" {
                            for_each = try(or_statement.value.statements, [])
                            content {
                              # Support byte_match statements directly in OR within AND
                              dynamic "byte_match_statement" {
                                for_each = try(statement.value.type, null) == "byte_match" ? [statement.value] : []
                                content {
                                  search_string         = byte_match_statement.value.search_string
                                  positional_constraint = byte_match_statement.value.positional_constraint

                                  dynamic "field_to_match" {
                                    for_each = [1]
                                    content {
                                      dynamic "uri_path" {
                                        for_each = try(byte_match_statement.value.field_to_match_type, null) == "uri_path" ? [1] : []
                                        content {}
                                      }
                                      dynamic "method" {
                                        for_each = try(byte_match_statement.value.field_to_match_type, null) == "method" ? [1] : []
                                        content {}
                                      }
                                      dynamic "query_string" {
                                        for_each = try(byte_match_statement.value.field_to_match_type, null) == "query_string" ? [1] : []
                                        content {}
                                      }
                                      dynamic "body" {
                                        for_each = try(byte_match_statement.value.field_to_match_type, null) == "body" ? [1] : []
                                        content {}
                                      }
                                    }
                                  }

                                  dynamic "text_transformation" {
                                    for_each = try(byte_match_statement.value.text_transformations, [])
                                    content {
                                      priority = text_transformation.value.priority
                                      type     = text_transformation.value.type
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }

                      # Support byte_match statements directly in AND
                      dynamic "byte_match_statement" {
                        for_each = try(statement.value.type, null) == "byte_match" ? [statement.value] : []
                        content {
                          search_string       = byte_match_statement.value.search_string
                          positional_constraint = byte_match_statement.value.positional_constraint

                          dynamic "field_to_match" {
                            for_each = [1]
                            content {
                              dynamic "uri_path" {
                                for_each = try(byte_match_statement.value.field_to_match_type, null) == "uri_path" ? [1] : []
                                content {}
                              }
                              dynamic "method" {
                                for_each = try(byte_match_statement.value.field_to_match_type, null) == "method" ? [1] : []
                                content {}
                              }
                              dynamic "query_string" {
                                for_each = try(byte_match_statement.value.field_to_match_type, null) == "query_string" ? [1] : []
                                content {}
                              }
                              dynamic "body" {
                                for_each = try(byte_match_statement.value.field_to_match_type, null) == "body" ? [1] : []
                                content {}
                              }
                            }
                          }

                          dynamic "text_transformation" {
                            for_each = try(byte_match_statement.value.text_transformations, [])
                            content {
                              priority = text_transformation.value.priority
                              type     = text_transformation.value.type
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }

              # OrStatement
              dynamic "or_statement" {
                for_each = try(scope_down_statement.value.type, null) == "or" ? [scope_down_statement.value] : []
                content {
                  dynamic "statement" {
                    for_each = try(or_statement.value.statements, [])
                    content {
                      # Support nested AND statements within OR
                      dynamic "and_statement" {
                        for_each = try(statement.value.type, null) == "and" ? [statement.value] : []
                        content {
                          dynamic "statement" {
                            for_each = try(and_statement.value.statements, [])
                            content {
                              dynamic "byte_match_statement" {
                                for_each = try(statement.value.type, null) == "byte_match" ? [statement.value] : []
                                content {
                                  search_string         = byte_match_statement.value.search_string
                                  positional_constraint = byte_match_statement.value.positional_constraint

                                  dynamic "field_to_match" {
                                    for_each = [1]
                                    content {
                                      dynamic "uri_path" {
                                        for_each = try(byte_match_statement.value.field_to_match_type, null) == "uri_path" ? [1] : []
                                        content {}
                                      }
                                      dynamic "method" {
                                        for_each = try(byte_match_statement.value.field_to_match_type, null) == "method" ? [1] : []
                                        content {}
                                      }
                                      dynamic "query_string" {
                                        for_each = try(byte_match_statement.value.field_to_match_type, null) == "query_string" ? [1] : []
                                        content {}
                                      }
                                      dynamic "body" {
                                        for_each = try(byte_match_statement.value.field_to_match_type, null) == "body" ? [1] : []
                                        content {}
                                      }
                                    }
                                  }

                                  dynamic "text_transformation" {
                                    for_each = try(byte_match_statement.value.text_transformations, [])
                                    content {
                                      priority = text_transformation.value.priority
                                      type     = text_transformation.value.type
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                }
              }

              # NotStatement
              dynamic "not_statement" {
                for_each = try(scope_down_statement.value.type, null) == "not" ? [scope_down_statement.value] : []
                content {
                  dynamic "statement" {
                    for_each = [try(not_statement.value.statement, {})]
                    content {
                      # Support nested OR statement within NOT
                      dynamic "or_statement" {
                        for_each = try(statement.value.type, null) == "or" ? [statement.value] : []
                        content {
                          dynamic "statement" {
                            for_each = try(or_statement.value.statements, [])
                            content {
                              # NOTE: The Terraform AWS provider does not support and_statement
                              # nested within or_statement within not_statement.
                              # If you need AND logic within OR within NOT, use byte_match statements directly
                              # or restructure your rules to avoid this nesting.

                              # Support byte_match statements directly in OR within NOT
                              dynamic "byte_match_statement" {
                                for_each = try(statement.value.type, null) == "byte_match" ? [statement.value] : []
                                content {
                                  search_string         = byte_match_statement.value.search_string
                                  positional_constraint = byte_match_statement.value.positional_constraint

                                  dynamic "field_to_match" {
                                    for_each = [1]
                                    content {
                                      dynamic "uri_path" {
                                        for_each = try(byte_match_statement.value.field_to_match_type, null) == "uri_path" ? [1] : []
                                        content {}
                                      }
                                      dynamic "method" {
                                        for_each = try(byte_match_statement.value.field_to_match_type, null) == "method" ? [1] : []
                                        content {}
                                      }
                                      dynamic "query_string" {
                                        for_each = try(byte_match_statement.value.field_to_match_type, null) == "query_string" ? [1] : []
                                        content {}
                                      }
                                      dynamic "body" {
                                        for_each = try(byte_match_statement.value.field_to_match_type, null) == "body" ? [1] : []
                                        content {}
                                      }
                                    }
                                  }

                                  dynamic "text_transformation" {
                                    for_each = try(byte_match_statement.value.text_transformations, [])
                                    content {
                                      priority = text_transformation.value.priority
                                      type     = text_transformation.value.type
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }

                      # Support nested AND statement within NOT
                      dynamic "and_statement" {
                        for_each = try(statement.value.type, null) == "and" ? [statement.value] : []
                        content {
                          dynamic "statement" {
                            for_each = try(and_statement.value.statements, [])
                            content {
                              dynamic "byte_match_statement" {
                                for_each = try(statement.value.type, null) == "byte_match" ? [statement.value] : []
                                content {
                                  search_string         = byte_match_statement.value.search_string
                                  positional_constraint = byte_match_statement.value.positional_constraint

                                  dynamic "field_to_match" {
                                    for_each = [1]
                                    content {
                                      dynamic "uri_path" {
                                        for_each = try(byte_match_statement.value.field_to_match_type, null) == "uri_path" ? [1] : []
                                        content {}
                                      }
                                      dynamic "method" {
                                        for_each = try(byte_match_statement.value.field_to_match_type, null) == "method" ? [1] : []
                                        content {}
                                      }
                                      dynamic "query_string" {
                                        for_each = try(byte_match_statement.value.field_to_match_type, null) == "query_string" ? [1] : []
                                        content {}
                                      }
                                      dynamic "body" {
                                        for_each = try(byte_match_statement.value.field_to_match_type, null) == "body" ? [1] : []
                                        content {}
                                      }
                                    }
                                  }

                                  dynamic "text_transformation" {
                                    for_each = try(byte_match_statement.value.text_transformations, [])
                                    content {
                                      priority = text_transformation.value.priority
                                      type     = text_transformation.value.type
                                    }
                                  }
                                }
                              }
                            }
                          }
                        }
                      }

                      # Support byte_match directly in NOT (for simple cases)
                      dynamic "byte_match_statement" {
                        for_each = try(statement.value.type, null) == "byte_match" ? [statement.value] : []
                        content {
                          search_string         = byte_match_statement.value.search_string
                          positional_constraint = byte_match_statement.value.positional_constraint

                          dynamic "field_to_match" {
                            for_each = [1]
                            content {
                              dynamic "uri_path" {
                                for_each = try(byte_match_statement.value.field_to_match_type, null) == "uri_path" ? [1] : []
                                content {}
                              }
                              dynamic "method" {
                                for_each = try(byte_match_statement.value.field_to_match_type, null) == "method" ? [1] : []
                                content {}
                              }
                              dynamic "query_string" {
                                for_each = try(byte_match_statement.value.field_to_match_type, null) == "query_string" ? [1] : []
                                content {}
                              }
                              dynamic "body" {
                                for_each = try(byte_match_statement.value.field_to_match_type, null) == "body" ? [1] : []
                                content {}
                              }
                            }
                          }

                          dynamic "text_transformation" {
                            for_each = try(byte_match_statement.value.text_transformations, [])
                            content {
                              priority = text_transformation.value.priority
                              type     = text_transformation.value.type
                            }
                          }
                        }
                      }

                      # Support IP set reference in NOT (e.g. exclude allowlisted IPs from a managed rule group)
                      dynamic "ip_set_reference_statement" {
                        for_each = try(statement.value.type, null) == "ip_set" ? [statement.value] : []
                        content {
                          arn = aws_wafv2_ip_set.custom[ip_set_reference_statement.value.ip_set_key].arn
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      override_action {
        dynamic "none" {
          for_each = rule.value.override_action == "none" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = rule.value.override_action == "count" ? [1] : []
          content {}
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = try(rule.value.visibility_config.cloudwatch_metrics_enabled, true)
        sampled_requests_enabled   = try(rule.value.visibility_config.sampled_requests_enabled, true)
        metric_name                = try(rule.value.visibility_config.metric_name, replace(rule.value.name, "-", ""))
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = var.visibility_config.cloudwatch_metrics_enabled
    sampled_requests_enabled   = var.visibility_config.sampled_requests_enabled
    metric_name                = var.visibility_config.metric_name
  }

  tags = merge(
    {
      Name      = var.name
      App_Alias = var.app_alias != null ? var.app_alias : ""
    },
    var.tags
  )
}

# CloudWatch Log Group for WAF logs
# NOTE: For CLOUDFRONT scope, the log group MUST be in us-east-1 region
# The log group is created even if logging is disabled, so it's ready for troubleshooting
resource "aws_cloudwatch_log_group" "waf_logs" {
  name              = var.log_group_name != null ? var.log_group_name : "aws-waf-logs-${var.name}"
  retention_in_days = var.log_retention_in_days

  tags = merge(
    {
      Name      = var.log_group_name != null ? var.log_group_name : "aws-waf-logs-${var.name}"
      App_Alias = var.app_alias != null ? var.app_alias : ""
    },
    var.tags
  )
}

# WAF Logging Configuration
# AWS WAF automatically adds the necessary resource-based policy to the log group when logging is enabled
# Only create this resource when enable_logging is true
# To enable logging for troubleshooting, set enable_logging = true and apply
resource "aws_wafv2_web_acl_logging_configuration" "this" {
  count = var.enable_logging ? 1 : 0

  resource_arn            = aws_wafv2_web_acl.this.arn
  log_destination_configs = [aws_cloudwatch_log_group.waf_logs.arn]

  lifecycle {
    create_before_destroy = true
  }
}

# Note: AWS WAF automatically adds a resource-based policy to the CloudWatch log group
# when logging is enabled. This policy allows AWS WAF to write logs to the log group.
# Terraform doesn't directly manage this policy - AWS handles it automatically when
# the logging configuration resource is created.
