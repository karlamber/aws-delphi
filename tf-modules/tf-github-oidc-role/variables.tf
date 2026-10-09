variable "region" {
  type        = string
  description = "AWS region."
}

variable "account_id" {
  type        = string
  description = "AWS account ID for this landscape environment."
}

variable "env" {
  type        = string
  description = "Environment acronym (dev, prod)."
}

variable "landscape" {
  type        = string
  description = "Landscape name."
}

variable "region_short" {
  type        = string
  description = "Short region code used in resource names (for example ue1)."
}

variable "artifact_bucket" {
  type        = string
  description = "Bucket that holds Lambda deployment zips. May live in another account."
}

variable "oidc_subjects" {
  type        = list(string)
  description = "GitHub OIDC subjects allowed to assume this role. Do not prefix with repo:."
}

# Present on every stack via account.hcl. This module does not use them.
variable "account_name" {
  type        = string
  description = "Account alias from account.hcl."
}

variable "aws_profile" {
  type        = string
  description = "AWS CLI profile from account.hcl."
}

variable "route53_account_id" {
  type        = string
  description = "Account that owns the public DNS zone."
}

variable "dns_manager_role_arn" {
  type        = string
  description = "Role assumed when writing public DNS records."
}
