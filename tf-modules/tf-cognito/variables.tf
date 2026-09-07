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
  description = "Alias for application specific resources"
  type        = string
  default     = ""
}

variable "detail" {
  description = "Unique value for identifying instance or function"
  type        = string
  default     = ""
}

variable "user_pools" {
  description = "Map of user pool names and their configurations"
  type = map(object({
    detail = string # Custom detail for pool-specific configurations
  }))
}

variable "applications" {
  description = "Map of applications and their configurations"
  type = map(object({
    user_pool                 = string        # Reference to the user pool
    name                      = string        # Application name
    domain                    = string        # Application domain
    allow_admin_create_user_only = bool      # Restrict user creation to admins
    saml_provider_name        = optional(string) # Name of the SAML provider (optional)
    saml_metadata_document_url = optional(string) # URL to SAML metadata document (optional)
    callback_urls             = list(string) # Callback URLs for OAuth
    logout_urls               = list(string) # Logout URLs for OAuth
    allowed_oauth_flows       = list(string) # OAuth flows (e.g., "code")
    allowed_oauth_scopes      = list(string) # OAuth scopes (e.g., "email")
    supported_identity_providers = list(string)
    attribute_mapping = map(string)
  }))
}

variable "custom_sign_in_attributes" {
  description = "Map of custom attributes for user pools"
  type = map(list(object({
    name                    = string        # Name of the custom attribute
    attribute_data_type     = string        # Data type (String, Number, etc.)
    required                = bool          # Whether the attribute is required
    mutable                 = bool          # Whether the attribute is mutable
    min_length              = optional(number) # Minimum string length (optional)
    max_length              = optional(number) # Maximum string length (optional)
  })))
  default = {}
}

variable "token_configuration" {
  description = "Token expiration configuration for user pool clients"
  type = map(object({
    access_token_validity  = optional(number, 60)      # minutes, default 1 hour
    id_token_validity      = optional(number, 60)     # minutes, default 1 hour
    refresh_token_validity = optional(number, 30)     # days, default 30 days
    token_validity_units = optional(object({
      access_token  = optional(string, "minutes")
      id_token      = optional(string, "minutes")
      refresh_token = optional(string, "days")
    }), {
      access_token  = "minutes"
      id_token      = "minutes"
      refresh_token = "days"
    })
  }))
  default = {}
}
