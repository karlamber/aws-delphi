# tf-lambda

**Provenance:** Deduplicated from landscape archives and sanitized.

## Required inputs

- `region`
- `account_id`
- `env`
- `landscape`
- `region_short`
- `log_retention`
- `config`
- `vpc_config`
- `custom_policy`
- `policy-std_lambda`
- `cloudwatch_logging_policy`
- `sqs_triggers`
- `api_gateway_triggers`
- `s3_triggers`
- `lambda_destinations`
- `additional_policy_arns`

## Usage

Reference from Terragrunt:

```hcl
terraform {
  source = "../../../modules/tf-lambda"
}
```
