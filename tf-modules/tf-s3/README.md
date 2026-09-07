# tf-s3

**Provenance:** Deduplicated from landscape archives and sanitized.

## Required inputs

- `region`
- `account_id`
- `env`
- `landscape`
- `region_short`
- `app_alias`
- `detail`
- `lifecycle_rule`
- `multipart_abort_days_after_initiation`
- `versioning_enabled`
- `encryption_enabled`
- `encryption_algorithm`
- `kms_key_id`
- `allowed_accounts`
- `organization_id`
- `cross_account_readonly`
- `cross_account_full_access`
- `full_access_roles`
- `readonly_roles`

## Usage

Reference from Terragrunt:

```hcl
terraform {
  source = "../../../modules/tf-s3"
}
```
