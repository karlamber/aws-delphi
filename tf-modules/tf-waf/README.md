# tf-waf

**Provenance:** Deduplicated from landscape archives and sanitized.

## Required inputs

- `name`
- `description`
- `scope`
- `resource_type`
- `default_action`
- `rules`
- `visibility_config`
- `app_alias`
- `tags`
- `enable_logging`
- `log_group_name`
- `log_retention_in_days`
- `maintenance_mode_enabled`
- `maintenance_allowed_ips`
- `ip_sets`

## Usage

Reference from Terragrunt:

```hcl
terraform {
  source = "../../../modules/tf-waf"
}
```
