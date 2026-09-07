# tf-iam-lambda-policy

**Provenance:** Deduplicated from landscape archives and sanitized.

## Required inputs

- `region`
- `account_id`
- `env`
- `landscape`
- `region_short`
- `app_alias`

## Usage

Reference from Terragrunt:

```hcl
terraform {
  source = "../../../modules/tf-iam-lambda-policy"
}
```
