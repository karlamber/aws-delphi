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
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region              = "${local.region}"
  profile             = "${local.aws_profile}"
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
  config = {
    encrypt      = true
    bucket       = "s3-${local.landscape}-${local.env}-${local.region_short}-terraform-state"
    key          = "${path_relative_to_include()}/terraform.tfstate"
    region       = local.region
    use_lockfile = true
    profile      = local.aws_profile
  }
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
