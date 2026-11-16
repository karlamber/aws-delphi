# aws-delphi — Delphi landscape (Argus CMDB)

This repository is the Terragrunt configuration for the Delphi landscape, which hosts the Argus CMDB. You clone it into an AWS account that already exists, fill in that account's number locally, and plan the stacks from here. Real account IDs, DNS role ARNs, and GitHub OIDC subjects stay in a gitignored `account.hcl`. The committed `account.hcl.example` shows the same fields with placeholders, so the repository can be published without those values.

## Layout

```text
aws-delphi/
├── root.hcl
├── tf-modules/           # landscape-local modules
└── aws-delphi-dev/       # member account folder (env=dev)
    ├── account.hcl.example   # committed placeholders
    ├── account.hcl           # gitignored — real IDs (copy from example)
    └── us-east-1/
        ├── vpc, cognito, cloudwatch_logging, github_oidc_*
        ├── s3-lambda-artifacts
        └── argus/
```

`root.hcl` generates the AWS provider and the S3 backend. Each directory that contains a `terragrunt.hcl` is one stack, and `aws-delphi-dev/account.hcl` supplies the account id, profile, DNS role, and OIDC subjects for every stack under that account.

## Prerequisites

The AWS account must already exist before you plan anything in this repository. Copy `aws-delphi-dev/account.hcl.example` to `aws-delphi-dev/account.hcl`, set `account_id` to that account's 12-digit number, set `account_name` to the name you use for the account, and set `aws_profile` to a local CLI profile that targets the same account. `root.hcl` pins `allowed_account_ids` to `account_id`, so a profile pointed at a different account fails before any resource is changed. Sign in and confirm the caller:

```bash
aws sso login --profile aws-delphi-dev
aws sts get-caller-identity --profile aws-delphi-dev
```

Use the profile name you wrote into `account.hcl` if it is not `aws-delphi-dev`.

Public hostnames in this sample use `example.net`, the reserved documentation zone, as in `argus-dev.example.net`. Before an apply, replace `example.net` in five files under `aws-delphi-dev/us-east-1/`: `cognito/terragrunt.hcl` (callback and logout URLs), `argus/lambda-argus_api/terragrunt.hcl` (`CORS_ORIGIN`), `argus/cloudfront/terragrunt.hcl` (distribution alias), `argus/tls/terragrunt.hcl` (certificate name and hosted zone), and `argus/dns_record/terragrunt.hcl` (record name and hosted zone). Repeat that edit in each environment folder you add later. Descriptions inside `tf-modules/` that mention `example.net` are examples, and changing them does not change what AWS creates. The `tls` and `dns_record` stacks assume a role that can write records in the zone you substitute, which means `route53_account_id` must be the account that owns the zone and `dns_manager_role_arn` must be a role your profile is allowed to assume. GitHub Actions deploys trust the subjects in `oidc_subjects`. Replace the example values with the organization and repository that will publish the API and the front end. Database passwords and other secrets are seeded outside Terraform. The SSM parameter module ignores later changes to those values, and secret material does not belong in any file in this repository.

`account.hcl` is gitignored. After you fill it in, `git status` should not list that file, and a search of the tree should not find access keys or private keys:

```bash
git status
git grep -E 'AKIA[0-9A-Z]{16}|BEGIN (RSA |OPENSSH )?PRIVATE' -- ':!*.lock.hcl' || true
```

## Plan

From `aws-delphi-dev`, the first plan creates the remote state bucket and validates every stack:

```bash
cd aws-delphi-dev
terragrunt plan --backend-bootstrap --all
```

`--backend-bootstrap` creates the encrypted state bucket declared in `root.hcl` when that bucket is missing. The name is `s3-delphi-<env>-ue1-<account_id>-terraform-state` in `us-east-1`, with the lock held by a lockfile in the same bucket. `--all` plans each stack under the account folder, which is how you confirm the configuration before any apply.

The Lambda before-hook runs during that plan and looks for its zip in the shared artifact bucket. Apply `us-east-1/s3-lambda-artifacts` once the state bucket exists, then plan again, if the Lambda unit stops because the bucket is not there yet. That bucket holds every Lambda zip in the account. Each function uses its own key, and the hook uploads a placeholder zip only when that key is missing.

## Run the application

Clone this repository, `argus-api-lambda`, and `argus-front-end` as sibling directories. This repository creates the account resources. The other two build the software and publish it onto those resources. Plan and apply the stacks here first, including `us-east-1/s3-lambda-artifacts`, the Argus Lambda, API Gateway, Cognito, and CloudFront. Seed the Aurora password for the `argus_lambda` user outside Terraform and apply `us-east-1/argus/rds/initial-config.sql` before the API is expected to read or write data.

Publish the API next. From `argus-api-lambda`, `npm run zip` produces `bundle.zip`, and the deploy section of that repository's README copies it to `s3-delphi-dev-ue1-<account_id>-lambda-artifacts` at `argus/dev/argus-argus_api.zip`, then calls `aws lambda update-function-code` on `lambda-argus-dev-ue1-argus_api`. That replaces the placeholder object the Lambda before-hook uploaded.

Publish the SPA last. From `argus-front-end`, the CloudFront section of that repository's README syncs `dist/` to `s3-argus-dev-ue1-<account_id>-cf-origin` and invalidates the distribution. The browser calls `/api` on the same host, and CloudFront forwards `/api/*` to API Gateway. Hosted-UI sign-in uses `https://argus-dev.example.net` because that hostname is the Cognito callback registered for the `argus` app client. The CloudFront domain name from `terragrunt output cloudfront_distribution_domain_name` serves the files as soon as the invalidation finishes. The alias answers after the DNS stack has written the record.

## Promotion

Promote by planning `dev`, then `tst`, then `prod`, with each stack planned on its own. This repository currently contains the `dev` account folder.

## Git: create the repo and push

```bash
cd ~/Projects/aws-delphi
git init -b main
git add .
git status   # confirm account.hcl is NOT staged
git commit -m "$(cat <<'EOF'
Initial aws-delphi landscape: Terragrunt + Argus CMDB stacks.

EOF
)"
gh repo create aws-delphi --private --source=. --remote=origin --push
```
