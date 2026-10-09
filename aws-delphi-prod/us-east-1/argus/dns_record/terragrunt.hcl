terraform {
  source = "../../../../tf-modules/tf-dns_record"

  before_hook "use_correct_terraform_version" {
    commands = ["init", "apply", "plan", "destroy", "output"]
    execute  = ["bash", "-c", "set -e; VERSION=$(grep -m1 -E 'required_version\\s*=' providers.tf | sed -n 's/.*= *\"\\([^\"]*\\)\".*/\\1/p' | sed 's/^~> *//;s/^>= *//;s/^> *//;s/^<= *//;s/^< *//;s/^[[:space:]]*//;s/[[:space:]]*$//'); if [ -n \"$VERSION\" ]; then tfenv use \"$VERSION\"; else echo 'No required_version found in providers.tf, skipping tfenv.'; fi"]
  }
}

# Assume the management-account DNS manager role to write records in fifty9.net
generate "provider_route53" {
  path      = "provider_route53.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  alias               = "route53"
  region              = "us-east-1"
  profile             = "${include.inputs.aws_profile}"
  allowed_account_ids = ["${include.inputs.route53_account_id}"]

  assume_role {
    role_arn = "${include.inputs.dns_manager_role_arn}"
  }
}
EOF
}

prevent_destroy = false

include {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "cloudfront" {
  config_path = "../cloudfront"

  mock_outputs = {
    cloudfront_distribution_domain_name = "d111111abcdef8.cloudfront.net"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

locals {
  app_alias = "argus"
}

inputs = {
  app_alias        = local.app_alias
  record_name      = "argus-${include.inputs.env}.fifty9.net"
  record_type      = "CNAME"
  records          = [dependency.cloudfront.outputs.cloudfront_distribution_domain_name]
  hosted_zone_name = "fifty9.net"
  ttl              = 300
}
