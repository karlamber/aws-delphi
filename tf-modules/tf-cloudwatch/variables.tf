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
