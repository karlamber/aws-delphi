terraform {
  source = "../../../../tf-modules/tf-lambda"

  before_hook "use_correct_terraform_version" {
    commands = ["init", "apply", "plan", "destroy", "output"]
    execute  = ["bash", "-c", "set -e; VERSION=$(grep -m1 -E 'required_version\\s*=' providers.tf | sed -n 's/.*= *\"\\([^\"]*\\)\".*/\\1/p' | sed 's/^~> *//;s/^>= *//;s/^> *//;s/^<= *//;s/^< *//;s/^[[:space:]]*//;s/[[:space:]]*$//'); if [ -n \"$VERSION\" ]; then tfenv use \"$VERSION\"; else echo 'No required_version found in providers.tf, skipping tfenv.'; fi"]
  }

  before_hook "copy_lambda_artifact" {
    commands = ["init", "apply", "plan"]
    execute = ["bash", "-c", <<-EOT
      set -e
      SOURCE_BUCKET="${include.inputs.artifact_bucket}"
      SOURCE_KEY="test-lambda.zip"
      DEST_BUCKET="${include.inputs.artifact_bucket}"
      DEST_KEY="${local.artifact_key}"
      AWS_PROFILE="59madison"

      echo "Checking if source artifact exists..."
      if ! aws --profile $AWS_PROFILE s3api head-object --bucket "$SOURCE_BUCKET" --key "$SOURCE_KEY" >/dev/null 2>&1; then
        echo "ERROR: Source artifact s3://$SOURCE_BUCKET/$SOURCE_KEY does not exist"
        exit 1
      fi

      echo "Checking if destination artifact exists..."
      if aws --profile $AWS_PROFILE s3api head-object --bucket "$DEST_BUCKET" --key "$DEST_KEY" >/dev/null 2>&1; then
        echo "Lambda artifact already exists at s3://$DEST_BUCKET/$DEST_KEY"
      else
        echo "Copying lambda artifact from s3://$SOURCE_BUCKET/$SOURCE_KEY to s3://$DEST_BUCKET/$DEST_KEY"
        aws --profile $AWS_PROFILE s3 cp "s3://$SOURCE_BUCKET/$SOURCE_KEY" "s3://$DEST_BUCKET/$DEST_KEY"
        echo "Copy completed successfully"
      fi
    EOT
    ]
  }
}

include {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  app_alias   = "argus"
  detail      = "argus_api"
  description = "Argus CMDB API Lambda (argus-api-lambda)"
  # Artifact bucket/key — align with argus-api-lambda deploy workflow / .env.deploy.example
  artifact_bucket = include.inputs.artifact_bucket
  artifact_key    = "${local.app_alias}/${include.inputs.env}/${local.app_alias}-${local.detail}.zip"
}

dependency "lambda_policy" {
  config_path = "../iam-lambda_policy"

  mock_outputs = {
    std_lambda = "arn:aws:iam::000000000000:policy/policy-mock-std_lambda"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "cloudwatch_logging_role" {
  config_path = "../../cloudwatch_logging"

  mock_outputs = {
    cloudwatch_logging_policy_arn = "arn:aws:iam::000000000000:policy/policy-mock-cloudwatch_logging"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "vpc" {
  config_path = "../../vpc"

  mock_outputs = {
    private_subnet_ids        = ["subnet-mockprivate000000001", "subnet-mockprivate000000002"]
    private_security_group_id = "sg-mockprivate0000000000"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "rds" {
  config_path = "../rds"

  mock_outputs = {
    cluster_endpoint = "mock-argus.cluster-xxxxxxxxxxxx.us-east-1.rds.amazonaws.com"
    cluster_port     = 5432
    database_name    = "argus"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "cognito" {
  config_path = "../../cognito"

  mock_outputs = {
    user_pool_ids       = { employees = "us-east-1_mockPoolId" }
    app_client_ids      = { argus = "mockclientid0000000000000000" }
    cognito_domain_urls = { employees = "https://mock.auth.us-east-1.amazoncognito.com" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

inputs = {
  cloudwatch_logging_policy = dependency.cloudwatch_logging_role.outputs.cloudwatch_logging_policy_arn
  policy-std_lambda         = dependency.lambda_policy.outputs.std_lambda

  vpc_config = {
    subnet_ids         = dependency.vpc.outputs.private_subnet_ids
    security_group_ids = [dependency.vpc.outputs.private_security_group_id]
  }

  config = {
    app_alias                      = local.app_alias
    detail                         = local.detail
    description                    = local.description
    architectures                  = ["x86_64"]
    handler                        = "handler.handler"
    memory_size                    = 256
    package_type                   = "Zip"
    runtime                        = "nodejs24.x"
    timeout                        = 30
    application_log_level          = "INFO"
    system_log_level               = "INFO"
    log_format                     = "JSON"
    s3_bucket                      = local.artifact_bucket
    s3_key                         = local.artifact_key
    environment = {
      variables = {
        PGHOST     = dependency.rds.outputs.cluster_endpoint
        PGPORT     = tostring(dependency.rds.outputs.cluster_port)
        PGDATABASE = dependency.rds.outputs.database_name
        PGUSER     = "argus_lambda"
        PG_SSL     = "true"
        PG_SSL_REJECT_UNAUTHORIZED = "false"
        # Seed PGPASSWORD and BASIC_AUTH_* via SSM or console — do not commit secrets here.
        PGPASSWORD                 = "<SEED_VIA_SSM_OR_CONSOLE>"
        AUTH_MODE                  = "cognito"
        CORS_ORIGIN                = "https://argus-${include.inputs.env}.fifty9.net"
        COGNITO_USER_POOL_ID       = dependency.cognito.outputs.user_pool_ids["employees"]
        COGNITO_APP_CLIENT_ID      = dependency.cognito.outputs.app_client_ids["argus"]
        COGNITO_ISSUER             = "https://cognito-idp.${include.inputs.region}.amazonaws.com/${dependency.cognito.outputs.user_pool_ids["employees"]}"
        COGNITO_DOMAIN_URL         = dependency.cognito.outputs.cognito_domain_urls["employees"]
        ADMIN_ROLE_CLAIM_VALUE     = "admin"
        APP_EDIT_ROLE_CLAIM_VALUE  = "app-edit"
        VIEWER_ROLE_CLAIM_VALUE    = "viewer"
        LOG_LEVEL                  = "info"
        SERVICE_NAME               = "argus-api"
        ENV_NAME                   = include.inputs.env
      }
    }
  }

  api_gateway_triggers = []
  sqs_triggers         = []
  s3_triggers          = []
  lambda_destinations  = {}

  custom_policy = {
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LambdaVPCAccess"
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface",
          "ec2:AssignPrivateIpAddresses",
          "ec2:UnassignPrivateIpAddresses",
        ]
        Resource = "*"
      },
      {
        Sid    = "ReadDeploymentPackage"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:GetObjectVersion"]
        Resource = "arn:aws:s3:::${local.artifact_bucket}/*"
      }
    ]
  }
}
