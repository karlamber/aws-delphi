# Apply this unit from a laptop once, after github_oidc_provider.
# Store the role ARN in the prod environment as AWS_ROLE_TO_ASSUME.
# job_workflow_ref pins the trust policy to terragrunt-apply.yml on main.
# A pull request runs a different ref, so it cannot assume this role.
# Prod apply also waits for the prod environment's required reviewers,
# and GitHub does not mint the token until they approve.

terraform {
  source = "../../../tf-modules/tf-github-oidc-iac-role"
}

include {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "github_oidc_provider" {
  config_path = "../github_oidc_provider"

  mock_outputs = {
    arn = "arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

locals {
  plan_role_name  = "role-${include.inputs.landscape}-${include.inputs.env}-${include.inputs.region_short}-github_oidc_iac_plan"
  apply_role_name = "role-${include.inputs.landscape}-${include.inputs.env}-${include.inputs.region_short}-github_oidc_iac_apply"
}

inputs = {
  mode                 = "apply"
  role_name            = local.apply_role_name
  oidc_provider_arn    = dependency.github_oidc_provider.outputs.arn
  oidc_subject         = include.inputs.iac_apply_oidc_subject
  job_workflow_ref     = include.inputs.iac_apply_job_workflow_ref
  state_bucket_name    = "s3-${include.inputs.landscape}-${include.inputs.env}-${include.inputs.region_short}-${include.inputs.account_id}-terraform-state"
  dns_manager_role_arn = include.inputs.dns_manager_role_arn
  protected_role_names = [local.plan_role_name, local.apply_role_name]
  account_id           = include.inputs.account_id
  region               = include.inputs.region
  env                  = include.inputs.env
  landscape            = include.inputs.landscape
  region_short         = include.inputs.region_short
}
