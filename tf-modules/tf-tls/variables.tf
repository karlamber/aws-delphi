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

variable "domain_name" {
  description = "FQDN for application secured by TLS Certificate"
  type        = string
}

variable "hosted_zone_name" {
  description = "DNS Zone value for TLS Certificate"
  type        = string
}
