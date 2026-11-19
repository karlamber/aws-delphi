variable "mode" {
  description = "plan grants read access plus state-lock writes. apply grants write access for the services this landscape creates."
  type        = string

  validation {
    condition     = contains(["plan", "apply"], var.mode)
    error_message = "mode must be plan or apply."
  }
}

variable "role_name" {
  description = "IAM role name. The landscape naming formula is applied by the Terragrunt unit."
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the existing GitHub OIDC provider in this account. This module does not create a second provider."
  type        = string
}

variable "oidc_subject" {
  description = "Exact token.actions.githubusercontent.com:sub value, including the repo: prefix. Example: repo:ORG/aws-delphi:environment:dev-plan. Repositories that issue immutable subjects use repo:ORG@ORG_ID/aws-delphi@REPO_ID:environment:NAME."
  type        = string
}

variable "job_workflow_ref" {
  description = "When non-empty, the trust policy also requires token.actions.githubusercontent.com:job_workflow_ref to match. Use this on the apply role. Leave empty on the plan role, because a pull request runs the workflow from the merge ref rather than refs/heads/main."
  type        = string
  default     = ""
}

variable "state_bucket_name" {
  description = "Remote state bucket name from root.hcl. The plan role may write only the .tflock objects in this bucket."
  type        = string
}

variable "dns_manager_role_arn" {
  description = "Route 53 role assumed by the tls and dns_record stacks. Both roles may assume it. The role's trust policy, which lives in the DNS account, must list these role ARNs."
  type        = string
}

variable "protected_role_names" {
  description = "IAM role names the apply role must not delete or rewrite. Includes the plan role and the apply role."
  type        = list(string)
}

variable "account_id" {
  type = string
}

variable "region" {
  type = string
}

variable "env" {
  type = string
}

variable "landscape" {
  type = string
}

variable "region_short" {
  type = string
}
