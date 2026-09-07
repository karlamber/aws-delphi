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
}

# Module Specific Variables
# The following variables are required for specific resource values

variable "app_alias" {
  description = "Alias for application specific resources"
  type        = string
  default     = ""
}

variable "detail" {
  description = "Unique value for identifying instance or function"
  type        = string
  default     = ""
}

variable "lifecycle_rule" {
  description = "Lifecycle rule for the bucket"
  type = object({
    status    = string  # "Enabled" or "Disabled" - controls whether the lifecycle rule is active
    prefix    = string  # Prefix to apply the lifecycle rule to (empty string for all objects)
    transitions = list(object({
      days          = number
      storage_class = string
    }))
    expiration = optional(number)  # Optional number of days after which objects will be deleted
  })
  default = null
}

variable "multipart_abort_days_after_initiation" {
  description = <<-EOT
    If set, abort incomplete multipart uploads after this many days since initiation.
    If null (default), no lifecycle rule is added for incomplete multipart uploads.
  EOT
  type        = number
  default     = null
  nullable    = true

  validation {
    condition     = var.multipart_abort_days_after_initiation == null || var.multipart_abort_days_after_initiation >= 1
    error_message = "multipart_abort_days_after_initiation must be null or >= 1."
  }
}

variable "versioning_enabled" {
  description = "Enable versioning for the bucket"
  type        = bool
  default     = false
}

variable "encryption_enabled" {
  description = "Enable encryption for the bucket"
  type        = bool
  default     = false
}

variable "encryption_algorithm" {
  description = "Encryption algorithm for the bucket"
  type        = string
  default     = "AES256"
}

variable "kms_key_id" {
  description = "KMS Key ID for bucket encryption"
  type        = string
  default     = null
}

variable "allowed_accounts" {
  description = "List of AWS account IDs that are allowed to assume the cross-account role"
  type        = list(string)
  default     = []
}

variable "organization_id" {
  description = "AWS Organization ID to restrict cross-account access to members of the organization"
  type        = string
  default     = ""
}

variable "cross_account_readonly" {
  description = "Whether to grant read-only access to the cross-account role"
  type        = bool
  default     = false
}

variable "cross_account_full_access" {
  description = "Whether to grant full access to the cross-account role"
  type        = bool
  default     = false
}

variable "full_access_roles" {
  description = "List of IAM role ARNs that need full access to the bucket"
  type        = list(string)
  default     = []
}

variable "readonly_roles" {
  description = "List of IAM role ARNs that need read-only access to the bucket"
  type        = list(string)
  default     = []
}
