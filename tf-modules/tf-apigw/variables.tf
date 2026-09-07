# Common Variables
# The following variables are used in every module

variable "region" {
  description = "The AWS region where resources will be created."
  type        = string
}

variable "account_id" {
  description = "AWS account ID."
  type        = string
}

variable "env" {
  description = "Environment acronym"
  type        = string
}

variable "landscape" {
  description = "Landscape name"
  type        = string
}

variable "region_short" {
  description = "Shortened version of the AWS Region for naming resources"
  type        = string
}

# Module Specific Variables

variable "app_alias" {
  description = "Alias for application-specific resources (e.g. argus)."
  type        = string
}

variable "detail" {
  description = "Short suffix distinguishing this API within the app (e.g. api)."
  type        = string
}

variable "lambda_function_name" {
  description = "Name of the Lambda function to invoke (for aws_lambda_permission)."
  type        = string
}

variable "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function (for API Gateway AWS_PROXY integration)."
  type        = string
}

variable "description" {
  description = "Description on the HTTP API."
  type        = string
  default     = ""
}

variable "detailed_metrics_enabled" {
  description = "Whether detailed metrics are enabled on the default stage route settings."
  type        = bool
  default     = false
}

variable "throttling_burst_limit" {
  description = "Throttle burst limit for the default stage. When null, falls back to the AWS HTTP API account default (5000). DO NOT set to 0 - AWS persists 0 as 'deny every request' (returns 429)."
  type        = number
  default     = null
}

variable "throttling_rate_limit" {
  description = "Throttle rate limit (RPS) for the default stage. When null, falls back to the AWS HTTP API account default (10000). DO NOT set to 0 - AWS persists 0 as 'deny every request' (returns 429)."
  type        = number
  default     = null
}

variable "enable_access_logs" {
  description = "Whether to enable access logging on the default stage. Creates a CloudWatch log group and writes one JSON record per request, including integration status and error message - useful for diagnosing 4xx/5xx responses."
  type        = bool
  default     = false
}

variable "access_log_retention_days" {
  description = "Retention (in days) for the access log group. Only used when enable_access_logs is true."
  type        = number
  default     = 14
}

# JWT Authorizer (Cognito-compatible)
#
# Two-knob design for phased rollouts:
#   1. `jwt_authorizer` (this variable) provisions the authorizer resource but
#      attaches it to nothing.
#   2. `default_route_authorization_type` flips the $default route from "NONE"
#      to "JWT" (all-or-nothing cutover).
#   3. `authorized_route_keys` attaches the authorizer to specific routes only,
#      leaving $default untouched - use this to canary the JWT path during
#      testing while the rest of the API continues to use whatever auth the
#      Lambda performs internally.
variable "jwt_authorizer" {
  description = "Optional JWT authorizer (Cognito-compatible) provisioned on the API. When null, no authorizer is created and the API remains unauthenticated. Attach the authorizer to routes via default_route_authorization_type and/or authorized_route_keys."
  type = object({
    issuer           = string
    audience         = list(string)
    identity_sources = optional(list(string), ["$request.header.Authorization"])
    name             = optional(string)
  })
  default = null
}

variable "default_route_authorization_type" {
  description = "Authorization type for the $default route. Use \"NONE\" to keep the route unauthenticated (e.g. while the Lambda still performs basic auth) or \"JWT\" to require a valid JWT for every request. When \"JWT\", jwt_authorizer must be set."
  type        = string
  default     = "NONE"
  validation {
    condition     = contains(["NONE", "JWT"], var.default_route_authorization_type)
    error_message = "default_route_authorization_type must be \"NONE\" or \"JWT\"."
  }
}

variable "authorized_route_keys" {
  description = "Optional list of API Gateway v2 route keys (e.g. \"GET /api/jwt-test\") attached to the JWT authorizer without flipping the $default route. Per-route routes take precedence over $default in API Gateway v2 routing, so this lets you canary JWT on a small surface during a phased rollout. Requires jwt_authorizer to be set."
  type        = list(string)
  default     = []
}
