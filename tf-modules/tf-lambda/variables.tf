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
  type = string
}

variable "landscape" {
  description = "Landscape name"
  type = string
}

variable "region_short" {
  description = "Shortened version of the AWS Region for naming resources"
}

variable "log_retention" {
  description = "Number of days to retain CloudWatch logs for the Lambda function"
  type        = number
  default     = 30
}

# Module Specific Variables
# The following variables are required for specific resource values
variable "config" {
  type = object({
    app_alias                      = string
    detail                         = string
    architectures                  = list(string)
    description                    = string
    handler                        = string
    memory_size                    = number
    package_type                   = string
    runtime                        = string
    timeout                        = number
    log_format                     = optional(string, "Text")
    application_log_level          = optional(string)
    system_log_level               = optional(string)
    tracing_mode                   = optional(string, "PassThrough")
    publish                        = optional(bool, false)
    skip_destroy                   = optional(bool, false)
    reserved_concurrent_executions = optional(number, -1)
    ephemeral_storage_size         = optional(number, 512)
    layers                         = optional(list(string), [])
    code_signing_config_arn        = optional(string)
    kms_key_arn                    = optional(string)
    source_code_hash               = optional(string)
    filename                       = optional(string)
    image_uri                      = optional(string)
    s3_bucket                      = optional(string)
    s3_key                         = optional(string)
    s3_object_version              = optional(string)
    environment = optional(object({
      variables = map(string)
    }))
  })

  validation {
    condition = (
      var.config.package_type == "Image" ?
      (
        var.config.image_uri != null &&
        var.config.filename == null &&
        var.config.s3_bucket == null &&
        var.config.s3_key == null &&
        var.config.s3_object_version == null
      ) :
      var.config.package_type == "Zip" ?
      (
        var.config.image_uri == null &&
        var.config.runtime != null &&
        var.config.handler != null &&
        (
          var.config.filename != null ||
          (var.config.s3_bucket != null && var.config.s3_key != null)
        )
      ) :
      true
    )

    error_message = "For package_type \"Image\", set image_uri and leave filename/s3_* null. For \"Zip\", provide runtime, handler, and either filename or s3_bucket + s3_key (image_uri must be null)."
  }
}

variable "vpc_config" {
  description = "Optional VPC configuration for the Lambda function."
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null

  validation {
    condition     = var.vpc_config == null ? true : (length(var.vpc_config.subnet_ids) > 0 && length(var.vpc_config.security_group_ids) > 0)
    error_message = "When vpc_config is provided, both subnet_ids and security_group_ids must be non-empty lists."
  }
}

variable "custom_policy" {
  description = "Custom IAM policy content for the Lambda. Set to null if not needed."
  type        = any
  default     = null
}

variable "policy-std_lambda" {
  description = "ARN of PD Standard Lambda Policy"
  type = string
}

variable "cloudwatch_logging_policy" {
  description = "ARN of Cloudwatch Logging Policy"
  type = string
}

variable "sqs_triggers" {
  description = "List of triggers for the Lambda function, each with event_source_arn, batch_size, and enabled."
  type = list(
    object({
      event_source_arn = string
      batch_size       = number
      enabled          = bool
    })
  )
  default = []
}

variable "api_gateway_triggers" {
  description = "List of API Gateway triggers for the Lambda function."
  type = list(
    object({
      api_url = string
      resource = string
      method = string
    })
  )
  default = []
}

variable "s3_triggers" {
  description = "List of s3 triggers for the Lambda function."
  type = list(
    object({
      s3_arn = string
    })
  )
  default = []
}

variable "lambda_destinations" {
  description = "Map of Lambda destinations for success and failure, including retry attempts"
  type = map(object({
    destination_arn       = string  # ARN of the destination (SQS, SNS, Lambda, EventBridge)
    maximum_retry_attempts = optional(number, 2)  # Default retry attempts = 2
  }))
  default = {}
}

variable "additional_policy_arns" {
  description = "List of additional IAM policy ARNs to attach to the Lambda role"
  type        = list(string)
  default     = []
}
