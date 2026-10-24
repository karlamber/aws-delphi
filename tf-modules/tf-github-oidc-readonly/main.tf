module "github_oidc_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  version = "5.60.0"

  name        = "role-${var.landscape}-${var.env}-${var.region_short}-github_oidc_readonly"
  description = "Read-only role for a manual Prowler scan. Cannot deploy."
  subjects    = var.oidc_subjects
}

resource "aws_iam_role_policy_attachment" "security_audit" {
  role       = module.github_oidc_role.name
  policy_arn = "arn:aws:iam::aws:policy/SecurityAudit"
}
