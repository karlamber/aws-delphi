# Account-wide bucket for Lambda deployment zips. Each Lambda uses its own object key.

terraform {
  source = "../../../tf-modules/tf-s3"

  before_hook "use_correct_terraform_version" {
    commands = ["init", "apply", "plan", "destroy", "output"]
    execute  = ["bash", "-c", "set -e; VERSION=$(grep -m1 -E 'required_version\\s*=' providers.tf | sed -n 's/.*= *\"\\([^\"]*\\)\".*/\\1/p' | sed 's/^~> *//;s/^>= *//;s/^> *//;s/^<= *//;s/^< *//;s/^[[:space:]]*//;s/[[:space:]]*$//'); if [ -n \"$VERSION\" ]; then tfenv use \"$VERSION\"; else echo 'No required_version found in providers.tf, skipping tfenv.'; fi"]
  }
}

include {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

inputs = {
  region       = include.inputs.region
  account_id   = include.inputs.account_id
  env          = include.inputs.env
  landscape    = include.inputs.landscape
  region_short = include.inputs.region_short

  # Landscape slot: this bucket is shared by every Lambda in aws-delphi-dev.
  app_alias = include.inputs.landscape
  detail    = "lambda-artifacts"

  versioning_enabled                    = true
  encryption_enabled                    = true
  multipart_abort_days_after_initiation = 7
}
