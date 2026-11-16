terraform {
  source = "../../../../tf-modules/tf-ssm_param"

  before_hook "use_correct_terraform_version" {
    commands = ["init", "apply", "plan", "destroy", "output"]
    execute  = ["bash", "-c", "set -e; VERSION=$(grep -m1 -E 'required_version\\s*=' providers.tf | sed -n 's/.*= *\"\\([^\"]*\\)\".*/\\1/p' | sed 's/^~> *//;s/^>= *//;s/^> *//;s/^<= *//;s/^< *//;s/^[[:space:]]*//;s/[[:space:]]*$//'); if [ -n \"$VERSION\" ]; then tfenv use \"$VERSION\"; else echo 'No required_version found in providers.tf, skipping tfenv.'; fi"]
  }
}

include {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  app_alias = "argus"
}

dependency "argus-rds" {
  config_path = "../rds"

  mock_outputs = {
    cluster_endpoint = "mock-argus.cluster-xxxxxxxxxxxx.us-east-1.rds.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = {
  parameters = [

    {
      comp        = "AURORA"
      app_alias   = upper(local.app_alias)
      name        = "WRITE_DB_HOST"
      value       = dependency.argus-rds.outputs.cluster_endpoint
 
      type        = "String"
      description = "AuroraDB Host used to connect to Argus DB for write"
    },
    {
      comp        = "AURORA"
      app_alias   = upper(local.app_alias)
      name        = "USERNAME"
      value       = "${local.app_alias}_service_acct"
      type        = "String"
      description = "Non DBO username for argus database"
    },
    {
      comp        = "AURORA"
      app_alias   = upper(local.app_alias)
      name        = "PASSWORD"
      value       = "<SEED_OUTSIDE_TERRAFORM>"
      type        = "SecureString"
      description = "Non DBO password for argus database"
    },
    {
      comp        = "ENV"
      app_alias   = upper(local.app_alias)
      name        = "LOG_LEVEL"
      value       = "debug"
      type        = "String"
      description = "Log level for argus"
    },
  ]
}
