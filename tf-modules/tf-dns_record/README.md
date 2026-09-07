# tf-dns_record

## Description

Creates a Route53 record in a public hosted zone that lives in the Route53 account. The aliased provider `aws.route53` assumes the DNS manager role in the Route53 account.

## Usage

Reference from Terragrunt:

```hcl
terraform {
  source = "../../../../tf-modules/tf-dns_record"
}

generate "provider_route53" {
  path      = "provider_route53.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  alias               = "route53"
  region              = "us-east-1"
  profile             = "aws-EXAMPLE-dev"
  allowed_account_ids = ["000000000000"]

  assume_role {
    role_arn = "arn:aws:iam::000000000000:role/role-EXAMPLE-root-ue1-dns_manager"
  }
}
EOF
}
```

## Requirements

- Terraform `~> 1.14.0`
- AWS provider `~> 6.0`
- Aliased provider `aws.route53` that can assume the DNS manager role in the Route53 account

## Inputs

| Name | Description | Type | Required |
| --- | --- | --- | --- |
| region | AWS region | `string` | yes |
| account_id | AWS account ID | `string` | yes |
| env | Environment acronym | `string` | yes |
| landscape | Landscape name | `string` | yes |
| region_short | Short region code | `string` | yes |
| app_alias | Application alias | `string` | no |
| record_name | FQDN of the DNS record | `string` | yes |
| record_type | Record type (A, CNAME, TXT, …) | `string` | no (default CNAME) |
| records | Record values | `list(string)` | yes |
| hosted_zone_name | Public hosted zone in the Route53 account | `string` | yes |
| ttl | TTL in seconds (not used for alias records) | `number` | no (default 300) |
| allow_overwrite | Overwrite an existing record | `bool` | no (default true) |
| alias | Optional alias target (CloudFront, ALB, …) | `object` | no |

## Outputs

| Name | Description |
| --- | --- |
| dns_record_name | Record name |
| dns_record_fqdn | Record FQDN |
| dns_record_type | Record type |
| dns_record_zone_id | Hosted zone ID |
| dns_record_records | Record values |
