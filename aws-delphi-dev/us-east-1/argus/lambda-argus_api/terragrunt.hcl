terraform {
  source = "../../../../tf-modules/tf-lambda"

  before_hook "use_correct_terraform_version" {
    commands = ["init", "apply", "plan", "destroy", "output"]
    execute  = ["bash", "-c", "set -e; VERSION=$(grep -m1 -E 'required_version\\s*=' providers.tf | sed -n 's/.*= *\"\\([^\"]*\\)\".*/\\1/p' | sed 's/^~> *//;s/^>= *//;s/^> *//;s/^<= *//;s/^< *//;s/^[[:space:]]*//;s/[[:space:]]*$//'); if ! command -v tfenv >/dev/null 2>&1; then echo 'tfenv is not installed, skipping version switch.'; exit 0; fi; if [ -n \"$VERSION\" ]; then tfenv use \"$VERSION\"; else echo 'No required_version found in providers.tf, skipping tfenv.'; fi"]
  }

  # Shared aws-delphi-dev zip bucket. Creates this Lambda's key only when the object is missing.
  before_hook "ensure_lambda_zip" {
    commands = ["plan", "apply"]
    execute = ["bash", "-c", <<-EOT
      set -euo pipefail
      BUCKET="${dependency.s3_lambda_artifacts.outputs.bucket_name}"
      KEY="${local.artifact_key}"
      AWS_PROFILE="${include.inputs.aws_profile}"
      # GitHub-hosted runners have no AWS profile. OIDC credentials are already in the environment.
      if [ -n "$${GITHUB_ACTIONS:-}" ] || [ -z "$AWS_PROFILE" ]; then
        aws_cli=(aws)
      else
        aws_cli=(aws --profile "$AWS_PROFILE")
      fi

      if "$${aws_cli[@]}" s3api head-object --bucket "$BUCKET" --key "$KEY" >/dev/null 2>&1; then
        echo "Lambda artifact already exists at s3://$BUCKET/$KEY"
        exit 0
      fi

      tmp=$(mktemp -d)
      trap 'rm -rf "$tmp"' EXIT
      cat > "$tmp/handler.js" <<'JS'
exports.handler = async () => ({
  statusCode: 200,
  headers: { "content-type": "application/json" },
  body: JSON.stringify({ status: "placeholder" }),
});
JS
      TMP_ARTIFACT="$tmp" python3 - <<'PY'
import os
import pathlib
import zipfile

root = pathlib.Path(os.environ["TMP_ARTIFACT"])
with zipfile.ZipFile(root / "placeholder.zip", "w", compression=zipfile.ZIP_DEFLATED) as archive:
    archive.write(root / "handler.js", "handler.js")
PY
      echo "Uploading placeholder zip to s3://$BUCKET/$KEY"
      "$${aws_cli[@]}" s3 cp "$tmp/placeholder.zip" "s3://$BUCKET/$KEY" --content-type application/zip
    EOT
    ]
  }
}

include {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

locals {
  app_alias    = "argus"
  detail       = "argus_api"
  description  = "Argus CMDB API Lambda (easycmdb-api)"
  artifact_key = "${local.app_alias}/${include.inputs.env}/${local.app_alias}-${local.detail}.zip"
}

dependency "s3_lambda_artifacts" {
  config_path = "../../s3-lambda-artifacts"

  mock_outputs = {
    bucket_name = "s3-mock-lambda"
    bucket_arn  = "arn:aws:s3:::s3-mock-lambda"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "init"]
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
    s3_bucket                      = dependency.s3_lambda_artifacts.outputs.bucket_name
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
        CORS_ORIGIN                = "https://argus-${include.inputs.env}.example.net"
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
        Resource = "${dependency.s3_lambda_artifacts.outputs.bucket_arn}/*"
      }
    ]
  }
}
