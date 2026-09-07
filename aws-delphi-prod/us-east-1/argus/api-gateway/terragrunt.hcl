terraform {
  source = "../../../../tf-modules/tf-apigw"

  before_hook "use_correct_terraform_version" {
    commands = ["init", "apply", "plan", "destroy", "output"]
    execute  = ["bash", "-c", "set -e; VERSION=$(grep -m1 -E 'required_version\\s*=' providers.tf | sed -n 's/.*= *\"\\([^\"]*\\)\".*/\\1/p' | sed 's/^~> *//;s/^>= *//;s/^> *//;s/^< *//;s/^[[:space:]]*//;s/[[:space:]]*$//'); if [ -n \"$VERSION\" ]; then tfenv use \"$VERSION\"; else echo 'No required_version found in providers.tf, skipping tfenv.'; fi"]
  }
}

include {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "argus_api_lambda" {
  config_path = "../lambda-argus_api"

  mock_outputs = {
    lambda_function_name       = "lambda-mock-argus-argus_api"
    lambda_function_invoke_arn = "arn:aws:apigateway:us-east-1:lambda:path/2015-03-31/functions/arn:aws:lambda:us-east-1:000000000000:function:lambda-mock-argus-argus_api/invocations"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "cognito" {
  config_path = "../../cognito"

  mock_outputs = {
    user_pool_ids  = { employees = "us-east-1_mockPoolId" }
    app_client_ids = { argus = "mockclientid0000000000000000" }
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

locals {
  app_alias = "argus"
}

inputs = {
  region       = include.inputs.region
  account_id   = include.inputs.account_id
  env          = include.inputs.env
  landscape    = include.inputs.landscape
  region_short = include.inputs.region_short

  app_alias   = local.app_alias
  detail      = "api"
  description = "HTTP API for Argus SPA (/api) -> argus-api-lambda"

  lambda_function_name = dependency.argus_api_lambda.outputs.lambda_function_name
  lambda_invoke_arn    = dependency.argus_api_lambda.outputs.lambda_function_invoke_arn

  enable_access_logs        = true
  access_log_retention_days = 14

  jwt_authorizer = {
    issuer   = "https://cognito-idp.${include.inputs.region}.amazonaws.com/${dependency.cognito.outputs.user_pool_ids["employees"]}"
    audience = [dependency.cognito.outputs.app_client_ids["argus"]]
  }
  default_route_authorization_type = "JWT"
  authorized_route_keys            = []
}
