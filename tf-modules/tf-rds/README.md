# tf-rds

**Provenance:** Deduplicated from landscape archives and sanitized.

## Required inputs

- `region`
- `account_id`
- `env`
- `landscape`
- `region_short`
- `app_alias`
- `engine`
- `engine_version`
- `database_name`
- `master_username`
- `storage_encrypted`
- `create_kms_key`
- `kms_key_id`
- `backup_retention_period`
- `preferred_backup_window`
- `preferred_maintenance_window`
- `port`
- `serverless_min_capacity`
- `serverless_max_capacity`
- `deletion_protection`
- `vpc_security_group_ids`
- `subnet_ids`
- `subnet_tier`
- `availability_zone_ids`
- `create_parameter_group`
- `parameter_group_family`
- `parameter_group_name`
- `parameter_group_parameters`
- `enabled_cloudwatch_logs_exports`
- `performance_insights_enabled`
- `performance_insights_retention_period`
- `performance_insights_kms_key_id`

## Usage

Reference from Terragrunt:

```hcl
terraform {
  source = "../../../modules/tf-rds"
}
```
