locals {
  api_name = "apigw-${var.app_alias}-${var.env}-${var.region_short}-${var.detail}"
}

resource "aws_apigatewayv2_api" "this" {
  name          = local.api_name
  protocol_type = "HTTP"
  description   = var.description != "" ? var.description : null

  tags = {
    App_Alias = var.app_alias
    Name      = local.api_name
  }
}

resource "aws_apigatewayv2_integration" "lambda" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = var.lambda_invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  count = var.jwt_authorizer != null ? 1 : 0

  api_id           = aws_apigatewayv2_api.this.id
  authorizer_type  = "JWT"
  identity_sources = var.jwt_authorizer.identity_sources
  name             = coalesce(var.jwt_authorizer.name, "${local.api_name}-jwt")

  jwt_configuration {
    audience = var.jwt_authorizer.audience
    issuer   = var.jwt_authorizer.issuer
  }
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"

  authorization_type = var.default_route_authorization_type
  authorizer_id      = var.default_route_authorization_type == "JWT" ? aws_apigatewayv2_authorizer.jwt[0].id : null

  lifecycle {
    precondition {
      condition     = var.default_route_authorization_type != "JWT" || var.jwt_authorizer != null
      error_message = "default_route_authorization_type=\"JWT\" requires jwt_authorizer to be set."
    }
  }
}

# Per-route opt-in for the JWT authorizer. Each entry creates a specific route
# that requires a valid JWT; specific routes take precedence over $default in
# API Gateway v2, so this lets you canary the authorizer on a narrow surface
# (e.g. "GET /api/jwt-test") without affecting the rest of the API.
resource "aws_apigatewayv2_route" "authorized" {
  for_each = toset(var.authorized_route_keys)

  api_id    = aws_apigatewayv2_api.this.id
  route_key = each.value
  target    = "integrations/${aws_apigatewayv2_integration.lambda.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt[0].id

  lifecycle {
    precondition {
      condition     = var.jwt_authorizer != null
      error_message = "authorized_route_keys requires jwt_authorizer to be set."
    }
  }
}

resource "aws_cloudwatch_log_group" "access_logs" {
  count             = var.enable_access_logs ? 1 : 0
  name              = "/aws/apigateway/${local.api_name}/access-logs"
  retention_in_days = var.access_log_retention_days

  tags = {
    App_Alias = var.app_alias
    Name      = "/aws/apigateway/${local.api_name}/access-logs"
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  # IMPORTANT: AWS persists ThrottlingBurstLimit=0 / ThrottlingRateLimit=0 as
  # "deny every request" (returns 429), NOT as "no limit". A null variable from
  # the caller must therefore fall back to the AWS HTTP API account defaults
  # (5000 burst / 10000 rate) so unconfigured stages behave sensibly.
  default_route_settings {
    detailed_metrics_enabled = var.detailed_metrics_enabled
    throttling_burst_limit   = var.throttling_burst_limit != null ? var.throttling_burst_limit : 5000
    throttling_rate_limit    = var.throttling_rate_limit != null ? var.throttling_rate_limit : 10000
  }

  # Access logs include integrationStatus and integrationErrorMessage which
  # tell us exactly why API Gateway returned 4xx/5xx (e.g. Lambda throttle,
  # bad permission, integration timeout). Toggle off once the API is stable.
  dynamic "access_log_settings" {
    for_each = var.enable_access_logs ? [1] : []
    content {
      destination_arn = aws_cloudwatch_log_group.access_logs[0].arn
      format = jsonencode({
        requestId               = "$context.requestId"
        requestTime             = "$context.requestTime"
        httpMethod              = "$context.httpMethod"
        routeKey                = "$context.routeKey"
        path                    = "$context.path"
        status                  = "$context.status"
        protocol                = "$context.protocol"
        responseLength          = "$context.responseLength"
        sourceIp                = "$context.identity.sourceIp"
        userAgent               = "$context.identity.userAgent"
        integrationStatus       = "$context.integrationStatus"
        integrationErrorMessage = "$context.integrationErrorMessage"
        integrationLatency      = "$context.integrationLatency"
        responseLatency         = "$context.responseLatency"
        errorMessage            = "$context.error.message"
        errorResponseType       = "$context.error.responseType"
      })
    }
  }

  tags = {
    App_Alias = var.app_alias
    Name      = "${local.api_name}-default"
  }
}

resource "aws_lambda_permission" "apigw_invoke" {
  statement_id  = "AllowAPIGatewayV2Invoke"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  # Use the API's canonical execution_arn and a single wildcard. HTTP API v2
  # invokes Lambda with a 2-segment ARN suffix (`<stage>/<route-key>`), and
  # IAM `*` matches within a single segment, so the previous pattern `/*/*/*`
  # (3 wildcards, REST-API style) did NOT match the actual invocation ARN
  # and Lambda returned AccessDenied -> APIGW returned 500/API_CONFIGURATION_ERROR.
  # `${execution_arn}/*` is AWS's recommended pattern and matches any path.
  source_arn = "${aws_apigatewayv2_api.this.execution_arn}/*"
}
