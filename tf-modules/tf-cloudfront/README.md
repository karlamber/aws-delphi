# tf-cloudfront

**Provenance:** Deduplicated from landscape archives and sanitized.

## Required inputs

- `region`
- `account_id`
- `env`
- `region_short`
- `app_alias`
- `cloudfront_aliases`
- `cloudfront_certificate_arn`
- `cloudfront_default_root_object`
- `additional_origins`
- `default_cache_behavior`
- `ordered_cache_behaviors`
- `custom_error_responses`
- `geo_restriction`
- `response_headers_policy_name`
- `web_acl_id`
- `enable_default_waf`

## Usage

Reference from Terragrunt:

```hcl
terraform {
  source = "../../../modules/tf-cloudfront"
}
```
