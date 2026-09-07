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
  # First regional /21 of account block 10.0.0.0/20 (AWS 10.0.0.0/11).
  # Omit availability_zone_ids for minimal (first regional AZ only).
  # List of 1–3 AZ IDs, e.g. ["use1-az1"] or ["use1-az1", "use1-az2", "use1-az4"].
  availability_zone_ids   = ["use1-az1", "use1-az3"]
  vpc_cidr                = "10.0.0.0/21"
  create_internet_gateway = false
  create_nat_gateways     = false
  retention_in_days       = 7
}
