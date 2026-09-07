# tf-cognito

**Provenance:** Deduplicated from landscape archives and sanitized.

## Required inputs

- `region`
- `account_id`
- `env`
- `landscape`
- `region_short`
- `app_alias`
- `detail`
- `user_pools`
- `applications`
- `custom_sign_in_attributes`
- `token_configuration`

## Usage

Reference from Terragrunt:

```hcl
terraform {
  source = "../../../modules/tf-cognito"
}
```
