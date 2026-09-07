# tf-vpc

VPC with three-tier subnets for a **regional `/21`** (half of an account `/20` inside AWS `10.0.0.0/11`).

## Description

Creates a VPC, public / private / isolated subnets, route tables, optional IGW and NAT gateways, gateway endpoints (S3, DynamoDB), Secrets Manager interface endpoint, optional SSM endpoints, tier security groups, VPC flow logs, and CloudTrail.

### CIDR layout (relative to `vpc_cidr` `/21`)

| Tier | Size | AZ 0 | AZ 1 | AZ 2 |
|------|------|------|------|------|
| Public | `/25` | index 0 | index 1 | index 2 |
| Private | `/24` | `+2` | `+3` | `+4` (as `/24` from `/21`) |
| Isolated | `/25` | `/25` index 10 | 11 | 12 |
| Reserved | — | remainder of `/21` (not created) |

Example for `10.0.0.0/21`: public `10.0.0.0/25`, private `10.0.2.0/24`, isolated `10.0.5.0/25` (minimal 1 AZ).

AZ count is `length(availability_zone_ids)` (`1`–`3`). If `availability_zone_ids` is `null`, the module uses the **first AZ only** (minimal footprint).

## Usage

```hcl
terraform {
  source = "../../../tf-modules/tf-vpc"
}

inputs = {
  vpc_cidr                = "10.0.0.0/21"
  create_internet_gateway = true
  create_nat_gateways     = true
  retention_in_days       = 7
  # availability_zone_ids = ["use1-az1", "use1-az2", "use1-az4"]  # optional; default 1 AZ
}
```

Track allocations in workspace [`docs/network-allocations.yaml`](../../../docs/network-allocations.yaml).

## Requirements

| Name | Version |
|------|---------|
| terraform | see `providers.tf` |
| aws | (injected by Terragrunt root) |

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| region | AWS region | `string` | yes |
| account_id | AWS account ID | `string` | yes |
| env | Environment acronym | `string` | yes |
| landscape | Landscape name | `string` | yes |
| region_short | Short region name for resource naming | `string` | yes |
| vpc_cidr | Regional VPC CIDR (`/21`) | `string` | yes |
| create_internet_gateway | Create an IGW and public default route | `bool` | no (default `false`) |
| create_nat_gateways | Create one NAT per public subnet | `bool` | no (default `false`) |
| retention_in_days | Flow log retention | `number` | no (default `30`) |
| availability_zone_ids | AZ IDs (`1`–`3`); `null` = first AZ only | `list(string)` | no (default `null`) |
| create_ssm_vpc_endpoints | SSM / EC2 messages interface endpoints | `bool` | no (default `false`) |

## Outputs

| Name | Description |
|------|-------------|
| vpc_id | VPC ID |
| vpc_arn | VPC ARN |
| vpc_cidr_block | VPC CIDR |
| public_subnet_ids | Public subnet IDs |
| private_subnet_ids | Private subnet IDs |
| isolated_subnet_ids | Isolated subnet IDs |
| public_security_group_id | Public tier SG |
| private_security_group_id | Private tier SG |
| isolated_security_group_id | Isolated tier SG |
| nat_gateway_ids | NAT Gateway IDs |
| internet_gateway_id | IGW ID (or null) |
| availability_zone_ids | AZ IDs in use |
| … | See `outputs.tf` for endpoints, flow logs, CloudTrail |
