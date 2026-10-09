output "iam_role_arn" {
  description = "ARN of the GitHub Actions deploy role."
  value       = module.github_oidc_role.arn
}

output "iam_role_name" {
  description = "Name of the GitHub Actions deploy role."
  value       = module.github_oidc_role.name
}
