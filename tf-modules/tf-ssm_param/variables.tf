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

# Module Specific Variables
# The following variables are required for specific resource values

variable "parameters" {
  type = list(object({
    comp        = string
    app_alias   = string
    name        = string
    value       = string
    type        = string
    description = string
  }))
  description = "List of parameter details"
}
