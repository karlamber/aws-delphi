# tf-modules

Co-located Terraform modules for the **delphi** landscape.

Copied from the sanitized `examples/terraform-modules/modules` library plus `tf-apigw` for Argus HTTP API routing.

| Module | Purpose |
|--------|---------|
| `tf-vpc` | Regional `/21` VPC; `/25` public, `/24` private, `/25` isolated (1–3 AZs) |
| `tf-cognito` | User pool + app client for Argus auth |
| `tf-rds` | Aurora PostgreSQL for Argus CMDB |
| `tf-lambda` | Argus API Lambda |
| `tf-apigw` | HTTP API Gateway → Lambda |
| `tf-cloudfront` | Argus SPA distribution |
| `tf-tls` | ACM certificate; DNS validation via `aws.route53` in the Route53/mgmt account |
| `tf-dns_record` | Route53 record in fifty9.net via `aws.route53` in the Route53/mgmt account |
| `tf-s3` | SPA artifact bucket |
| `tf-cloudwatch` | CloudWatch logging role |
| `tf-iam-lambda-policy` | Standard Lambda execution policy |
| `tf-ssm_param` | SSM parameters |
| `tf-waf` | WAF (optional, attach to CloudFront) |

Reference from Terragrunt:

```hcl
terraform {
  source = "../../../tf-modules/tf-vpc"
}
```
