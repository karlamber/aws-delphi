terraform {
  source = "../../../tf-modules/tf-vpc"

  before_hook "use_correct_terraform_version" {
    commands = ["init", "apply", "plan", "destroy", "output"]
    execute  = ["bash", "-c", "set -e; VERSION=$(grep -m1 -E 'required_version\\s*=' providers.tf | sed -n 's/.*= *\"\\([^\"]*\\)\".*/\\1/p' | sed 's/^~> *//;s/^>= *//;s/^> *//;s/^<= *//;s/^< *//;s/^[[:space:]]*//;s/[[:space:]]*$//'); if [ -n \"$VERSION\" ]; then tfenv use \"$VERSION\"; else echo 'No required_version found in providers.tf, skipping tfenv.'; fi"]
  }
}

include {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependencies {
  paths = ["../cloudwatch_logging"]
}

inputs = {
  # First regional /21 of account block 10.0.48.0/20 (AWS 10.0.0.0/11).
  # Separate from aws-delphi-dev (10.0.0.0/20). Subnets follow the module's
  # relative /21 layout: public /25, private /24, isolated /25.
  availability_zone_ids   = ["use1-az1", "use1-az3"]
  vpc_cidr                = "10.0.48.0/21"
  create_internet_gateway = false
  create_nat_gateways     = false
  retention_in_days       = 7
}
