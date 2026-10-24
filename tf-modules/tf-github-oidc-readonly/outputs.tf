output "iam_role_arn" {
  description = "ARN to pass as role_arn when running the Prowler workflow."
  value       = module.github_oidc_role.arn
}

output "iam_role_name" {
  description = "Name of the read-only GitHub Actions role."
  value       = module.github_oidc_role.name
}
