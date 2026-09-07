# tf-ssm_param

**Provenance:** Deduplicated from landscape archives and sanitized.

## Required inputs

- `region`
- `account_id`
- `env`
- `landscape`
- `region_short`
- `parameters`

## Usage

Reference from Terragrunt:

```hcl
terraform {
  source = "../../../modules/tf-ssm_param"
}
```
