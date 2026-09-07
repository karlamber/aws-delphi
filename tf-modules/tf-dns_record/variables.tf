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
# The following variables are required for specific resource values

variable "app_alias" {
  description = "Alias for application specific resources"
  type        = string
  default     = ""
}

variable "record_name" {
  description = "The name of the DNS record (e.g., argus-dev.fifty9.net)"
  type        = string
}

variable "record_type" {
  description = "The type of DNS record (e.g., A, AAAA, CNAME, TXT, MX, NS, PTR, SOA, SRV)"
  type        = string
  default     = "CNAME"
}

variable "records" {
  description = "List of record values. For most record types, this is a list of strings. For alias records, use the alias variable instead."
  type        = list(string)
}

variable "hosted_zone_name" {
  description = "The name of the hosted zone in the Route53 account (e.g., fifty9.net)"
  type        = string
}

variable "ttl" {
  description = "The TTL (Time To Live) for the DNS record in seconds. Not used for alias records."
  type        = number
  default     = 300
}

variable "allow_overwrite" {
  description = "Allow creation of this record in Terraform to overwrite an existing record, if any."
  type        = bool
  default     = true
}

variable "alias" {
  description = "An alias block for Route53 alias records (e.g., for CloudFront, ALB, etc.). If provided, this takes precedence over records and ttl."
  type = object({
    name                   = string
    zone_id                = string
    evaluate_target_health = bool
  })
  default = null
}

