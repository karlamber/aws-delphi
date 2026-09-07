# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/lambda-${var.config.app_alias}-${var.env}-${var.region_short}-${var.config.detail}"
  retention_in_days = var.log_retention

  tags = {
    App_Alias = var.config.app_alias
    Name      = "/aws/lambda/lambda-${var.config.app_alias}-${var.env}-${var.region_short}-${var.config.detail}"
  }
}

resource "aws_iam_role" "this" {
  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
      Service = ["lambda.amazonaws.com","edgelambda.amazonaws.com"]
      }
    }]
    Version = "2012-10-17"
  })
  description           = null
  force_detach_policies = false
  max_session_duration  = 3600
  name                  = "role-${var.config.app_alias}-${var.env}-${var.region_short}-${var.config.detail}"
  name_prefix           = null
  path                  = "/service-role/"
  permissions_boundary  = null
  tags = {
    App_Alias = "${var.config.app_alias}"
    Name      = "role-${var.config.app_alias}-${var.env}-${var.region_short}-${var.config.detail}"
  }
}

resource "aws_lambda_function" "this" {
  architectures                  = var.config.architectures
  code_signing_config_arn        = var.config.code_signing_config_arn
  description                    = var.config.description
  function_name                  = "lambda-${var.config.app_alias}-${var.env}-${var.region_short}-${var.config.detail}"
  handler                        = var.config.handler
  kms_key_arn                    = var.config.kms_key_arn
  layers                         = var.config.layers
  memory_size                    = var.config.memory_size
  package_type                   = var.config.package_type
  publish                        = var.config.publish
  reserved_concurrent_executions = var.config.reserved_concurrent_executions
  role                           = resource.aws_iam_role.this.arn
  runtime                        = var.config.runtime
  skip_destroy                   = var.config.skip_destroy
  source_code_hash               = var.config.source_code_hash
  tags = {
    App_Alias = "${var.config.app_alias}"
    Name      = "lambda-${var.config.app_alias}-${var.env}-${var.region_short}-${var.config.detail}"
  }
  timeout                        = var.config.timeout

  depends_on = [aws_cloudwatch_log_group.lambda_logs]

  # Only one of filename, image_uri, or s3_bucket
  filename  = var.config.filename != null ? var.config.filename : null
  image_uri = var.config.image_uri != null ? var.config.image_uri : null
  s3_bucket = var.config.s3_bucket != null ? var.config.s3_bucket : null
  s3_key    = var.config.s3_bucket != null ? var.config.s3_key : null
  s3_object_version = var.config.s3_bucket != null ? var.config.s3_object_version : null

  ephemeral_storage {
    size = var.config.ephemeral_storage_size
  }

  logging_config {
    application_log_level = var.config.application_log_level
    log_format            = var.config.log_format
    log_group             = aws_cloudwatch_log_group.lambda_logs.name
    system_log_level      = var.config.system_log_level
  }

  tracing_config {
    mode = var.config.tracing_mode
  }

  dynamic "vpc_config" {
    for_each = var.vpc_config != null ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  dynamic "environment" {
    for_each = var.config.environment != null ? [var.config.environment] : []
    content {
      variables = environment.value.variables
    }
  }
}

# Integration (Linking SQS Queues to Lambda)
resource "aws_lambda_event_source_mapping" "sqs_triggers" {
  for_each = { for idx, trigger in var.sqs_triggers : idx => trigger }
  event_source_arn = each.value.event_source_arn
  function_name    = aws_lambda_function.this.function_name
  batch_size       = each.value.batch_size
  enabled          = each.value.enabled
}

# Integration (Linking API Gateway to Lambda)
resource "aws_lambda_permission" "api_gateway_triggers" {
  for_each = { for idx, trigger in var.api_gateway_triggers : idx => trigger }
  statement_id  = "AllowAPIGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn = "${each.value.api_url}/*/${each.value.method}/${each.value.resource}"
}

# Integration (Linking s3 Bucket to Lambda)
resource "aws_lambda_permission" "s3_triggers" {
  for_each = { for idx, trigger in var.s3_triggers : idx => trigger }
  statement_id  = "AllowAPIGatewayInvoke-${each.key}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "${each.value.s3_arn}"
}

resource "aws_lambda_function_event_invoke_config" "on_success" {
  for_each = { for key, dest in var.lambda_destinations : key => dest if key == "on_success" }

  function_name          = aws_lambda_function.this.function_name
  maximum_retry_attempts = each.value.maximum_retry_attempts

  destination_config {
    on_success {
      destination = each.value.destination_arn
    }
  }
}

resource "aws_lambda_function_event_invoke_config" "on_failure" {
  for_each = { for key, dest in var.lambda_destinations : key => dest if key == "on_failure" }

  function_name          = aws_lambda_function.this.function_name
  maximum_retry_attempts = each.value.maximum_retry_attempts

  destination_config {
    on_failure {
      destination = each.value.destination_arn
    }
  }
}

# Attach policies to the lambda
resource "aws_iam_policy" "custom_managed_policy" {
  count        = var.custom_policy != null ? 1 : 0
  name         = "policy-lambda-${var.config.app_alias}-${var.env}-${var.region_short}-${var.config.detail}"
  description  = "Custom IAM Policy designed for the ${aws_lambda_function.this.function_name} Lambda"
  tags = {
    App_Alias = "${var.config.app_alias}"
    Name      = "policy-lambda-${var.config.app_alias}-${var.env}-${var.region_short}-custom_managed_policy"
  }
  policy       = jsonencode(var.custom_policy)
}

resource "aws_iam_role_policy_attachment" "attach_custom_policy" {
  count      = var.custom_policy != null ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = aws_iam_policy.custom_managed_policy[count.index].arn
}

resource "aws_iam_role_policy_attachment" "attach_pd_policy" {
  role       = aws_iam_role.this.name
  policy_arn = var.policy-std_lambda
}

resource "aws_iam_role_policy_attachment" "cloudwatch_logging_policy" {
  role       = aws_iam_role.this.name
  policy_arn = var.cloudwatch_logging_policy
}

# Ensure VPC-enabled Lambdas have ENI permissions when vpc_config is set
resource "aws_iam_role_policy_attachment" "lambda_vpc_access" {
  count      = var.vpc_config != null ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Allow Lambda to pull container images from ECR when using Image package type
resource "aws_iam_role_policy_attachment" "lambda_ecr_pull" {
  count      = var.config.image_uri != null ? 1 : 0
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Attach additional policies to the Lambda role
resource "aws_iam_role_policy_attachment" "additional_policies" {
  for_each   = toset(var.additional_policy_arns)
  role       = aws_iam_role.this.name
  policy_arn = each.value
}
