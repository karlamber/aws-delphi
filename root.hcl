locals {
  account_vars = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars  = read_terragrunt_config(find_in_parent_folders("region.hcl"))

  landscape    = "delphi"
  region_short = join("", [for part in split("-", local.region) : substr(part, 0, 1)])

  account_name = local.account_vars.locals.account_name
  account_id   = local.account_vars.locals.account_id
  aws_profile  = local.account_vars.locals.aws_profile
  region       = local.region_vars.locals.region
  env          = local.account_vars.locals.env

  # GitHub Actions sets GITHUB_ACTIONS. Runners have no AWS profile; they use the
  # OIDC credentials from aws-actions/configure-aws-credentials. Laptops still
  # pass the profile named in account.hcl.
  in_github_actions = get_env("GITHUB_ACTIONS", "") != ""
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<-EOF
provider "aws" {
  region              = "${local.region}"
%{if !local.in_github_actions~}
  profile             = "${local.aws_profile}"
%{endif~}
  allowed_account_ids = ["${local.account_id}"]
  default_tags {
    tags = {
      Landscape     = "${local.landscape}"
      Environment   = "${local.env}"
      ProvisionedBy = "Terragrunt"
    }
  }
}
EOF
}

remote_state {
  backend = "s3"
  config = merge(
    {
      encrypt      = true
      bucket       = "s3-${local.landscape}-${local.env}-${local.region_short}-${local.account_id}-terraform-state"
      key          = "${path_relative_to_include()}/terraform.tfstate"
      region       = local.region
      use_lockfile = true
    },
    local.in_github_actions ? {} : { profile = local.aws_profile },
  )
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
}

inputs = merge(
  local.account_vars.locals,
  local.region_vars.locals,
  { region_short = local.region_short },
  { landscape = local.landscape }
)
