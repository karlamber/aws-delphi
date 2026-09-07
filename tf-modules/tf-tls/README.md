# tf-tls

## Description

ACM certificate in the workload account, with DNS validation records written in the Route53 account via provider alias `aws.route53`.

## Usage

Reference from Terragrunt:

```hcl
terraform {
  source = "../../../../tf-modules/tf-tls"
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
| domain_name | FQDN for the ACM certificate | `string` | yes |
| hosted_zone_name | Public hosted zone in the Route53 account | `string` | yes |

## Outputs

| Name | Description |
| --- | --- |
| certificate_arn | ACM certificate ARN after DNS validation completes |
| certificate_domain_name | Certificate domain name |
| certificate_validation_method | Validation method |
| validation_records | ACM domain validation options |
| certificate_validation_status | Validation resource ID |
