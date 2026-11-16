terraform {
  source = "../../../../tf-modules/tf-rds"

  before_hook "use_correct_terraform_version" {
    commands = ["init", "apply", "plan", "destroy", "output"]
    execute  = ["bash", "-c", "set -e; VERSION=$(grep -m1 -E 'required_version\\s*=' providers.tf | sed -n 's/.*= *\"\\([^\"]*\\)\".*/\\1/p' | sed 's/^~> *//;s/^>= *//;s/^> *//;s/^< *//;s/^[[:space:]]*//;s/[[:space:]]*$//'); if [ -n \"$VERSION\" ]; then tfenv use \"$VERSION\"; else echo 'No required_version found in providers.tf, skipping tfenv.'; fi"]
  }
}

include {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "vpc" {
  config_path = "../../vpc"

  mock_outputs = {
    isolated_subnet_ids         = ["subnet-mockisolated00000001", "subnet-mockisolated00000002"]
    isolated_security_group_id  = "sg-mockisolated000000000"
    availability_zone_ids       = ["use1-az1", "use1-az3"]
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

locals {
  app_alias   = "argus"
  subnet_tier = "isolated"
}

inputs = {
  app_alias         = local.app_alias
  subnet_tier       = local.subnet_tier
  database_name     = local.app_alias
  engine            = "aurora-postgresql"
  engine_version    = "17.4"
  master_username   = "postgres"
  storage_encrypted = true
  create_kms_key    = false
  subnet_ids = dependency.vpc.outputs.isolated_subnet_ids
  vpc_security_group_ids = [dependency.vpc.outputs.isolated_security_group_id]
  port                   = 5432
  serverless_min_capacity = 0
  serverless_max_capacity = 1
  deletion_protection     = false # set true in prod after validation
  availability_zone_ids   = dependency.vpc.outputs.availability_zone_ids
  create_parameter_group  = false
  parameter_group_family  = "aurora-postgresql17"
  backup_retention_period = 7
}
