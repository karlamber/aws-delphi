terraform {
  source = "../../../../tf-modules/tf-cloudfront"

  before_hook "use_correct_terraform_version" {
    commands = ["init", "apply", "plan", "destroy", "output"]
    execute  = ["bash", "-c", "set -e; VERSION=$(grep -m1 -E 'required_version\\s*=' providers.tf | sed -n 's/.*= *\"\\([^\"]*\\)\".*/\\1/p' | sed 's/^~> *//;s/^>= *//;s/^> *//;s/^<= *//;s/^< *//;s/^[[:space:]]*//;s/[[:space:]]*$//'); if [ -n \"$VERSION\" ]; then tfenv use \"$VERSION\"; else echo 'No required_version found in providers.tf, skipping tfenv.'; fi"]
  }
}

include {
  path   = find_in_parent_folders("root.hcl")
  expose = true
}

dependency "api_gateway" {
  config_path = "../api-gateway"

  mock_outputs = {
    api_endpoint = "https://mock.execute-api.us-east-1.amazonaws.com"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

dependency "tls" {
  config_path = "../tls"

  mock_outputs = {
    certificate_arn = "arn:aws:acm:us-east-1:000000000000:certificate/00000000-0000-0000-0000-000000000000"
  }
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "init"]
}

locals {
  app_alias     = "argus"
  api_origin_id = "${local.app_alias}-apigw-origin"
  domain_name   = "argus-${include.inputs.env}.fifty9.net"

  # AWS managed policies
  cache_caching_optimized          = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  cache_caching_disabled           = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  origin_all_viewer_except_host    = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
}

inputs = {
  region       = include.inputs.region
  account_id   = include.inputs.account_id
  env          = include.inputs.env
  region_short = include.inputs.region_short

  app_alias                  = local.app_alias
  cloudfront_aliases         = [local.domain_name]
  cloudfront_certificate_arn = dependency.tls.outputs.certificate_arn

  cloudfront_default_root_object = "index.html"

  # Default behavior serves the SPA from the module-created S3 origin
  # (s3-argus-{env}-{region_short}-cf-origin, origin_id argus-s3-origin).
  default_cache_behavior = {
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id        = local.cache_caching_optimized
    compress               = true
    default_ttl            = 0
    max_ttl                = 0
    min_ttl                = 0
    viewer_protocol_policy = "redirect-to-https"
    target_origin_id       = "${local.app_alias}-s3-origin"
  }

  additional_origins = {
    (local.api_origin_id) = {
      domain_name = replace(dependency.api_gateway.outputs.api_endpoint, "https://", "")
      origin_id   = local.api_origin_id
      origin_path = null
      custom_origin_config = {
        http_port                = 80
        https_port               = 443
        origin_keepalive_timeout = 5
        origin_protocol_policy   = "https-only"
        origin_read_timeout      = 30
        origin_ssl_protocols     = ["TLSv1.2"]
      }
    }
  }

  ordered_cache_behaviors = [
    {
      path_pattern             = "/api/*"
      target_origin_id         = local.api_origin_id
      allowed_methods          = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
      cached_methods           = ["GET", "HEAD"]
      compress                 = true
      cache_policy_id          = local.cache_caching_disabled
      origin_request_policy_id = local.origin_all_viewer_except_host
      viewer_protocol_policy   = "redirect-to-https"
      default_ttl              = 0
      max_ttl                  = 0
      min_ttl                  = 0
    }
  ]

  custom_error_responses = [
    {
      error_code            = 403
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 10
    },
    {
      error_code            = 404
      response_code         = 200
      response_page_path    = "/index.html"
      error_caching_min_ttl = 10
    }
  ]

  geo_restriction = {
    restriction_type = "whitelist"
    locations        = ["US"]
  }

  enable_default_waf = true
}
