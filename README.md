# aws-delphi — Delphi landscape (Argus CMDB)

This repository is the Terragrunt configuration for the Delphi landscape, which hosts the Argus CMDB. You clone it into an AWS account that already exists, fill in that account's number locally, and plan the stacks from here. Real account IDs, DNS role ARNs, and GitHub OIDC subjects stay in a gitignored `account.hcl`. The committed `account.hcl.example` shows the same fields with placeholders, so the repository can be published without those values.

## Layout

```text
aws-delphi/
├── root.hcl
├── tf-modules/           # landscape-local modules
├── aws-delphi-dev/       # member account folder (env=dev, VPC 10.0.0.0/21)
│   ├── account.hcl.example   # committed placeholders
│   ├── account.hcl           # gitignored — real IDs (copy from example)
│   └── us-east-1/
│       ├── vpc, cognito, cloudwatch_logging
│       ├── github_oidc_provider, github_oidc_role
│       ├── github_oidc_iac_plan, github_oidc_iac_apply
│       ├── s3-lambda-artifacts
│       └── argus/
└── aws-delphi-prod/      # member account folder (env=prod, VPC 10.0.48.0/21)
    └── (the same stacks as dev)
```

`root.hcl` generates the AWS provider and the S3 backend. Each directory that contains a `terragrunt.hcl` is one stack. `aws-delphi-dev/account.hcl` and `aws-delphi-prod/account.hcl` each supply the account id, profile, DNS role, and OIDC subjects for the stacks under that account. Dev owns `10.0.0.0/20` and prod owns `10.0.48.0/20`. The us-east-1 VPC in each folder is the first `/21` of that block, set in that folder's `us-east-1/vpc/terragrunt.hcl`.

## Prerequisites

The AWS account must already exist before you plan anything in this repository. Copy `account.hcl.example` to `account.hcl` inside the account folder you are applying (`aws-delphi-dev` or `aws-delphi-prod`), set `account_id` to that account's 12-digit number, set `account_name` to the name you use for the account, and set `aws_profile` to a local CLI profile that targets the same account. `root.hcl` pins `allowed_account_ids` to `account_id`, so a profile pointed at a different account fails before any resource is changed. Sign in and confirm the caller:

```bash
aws sso login --profile aws-delphi-dev
aws sts get-caller-identity --profile aws-delphi-dev
```

Use the profile name you wrote into `account.hcl` if it is not `aws-delphi-dev` or `aws-delphi-prod`. Prod uses the same sign-in commands with `--profile aws-delphi-prod`.

Public hostnames in this sample use `example.net`, the reserved documentation zone, as in `argus-dev.example.net` and `argus-prod.example.net`. Before an apply, replace `example.net` in five files under both `aws-delphi-dev/us-east-1/` and `aws-delphi-prod/us-east-1/`: `cognito/terragrunt.hcl` (callback and logout URLs), `argus/lambda-argus_api/terragrunt.hcl` (`CORS_ORIGIN`), `argus/cloudfront/terragrunt.hcl` (distribution alias), `argus/tls/terragrunt.hcl` (certificate name and hosted zone), and `argus/dns_record/terragrunt.hcl` (record name and hosted zone). Descriptions inside `tf-modules/` that mention `example.net` are examples, and changing them does not change what AWS creates. The `tls` and `dns_record` stacks assume a role that can write records in the zone you substitute, which means `route53_account_id` must be the account that owns the zone and `dns_manager_role_arn` must be a role your profile is allowed to assume. GitHub Actions deploys of the API and the front end trust the subjects in `oidc_subjects`. Replace the example values with the organization and repository that will publish those applications. The Terragrunt plan and apply roles use the separate `iac_*` subjects, and the Continuous integration section below is where those values, the GitHub Environments, and the one-time laptop apply of the roles are described. Database passwords and other secrets are seeded outside Terraform. The SSM parameter module ignores later changes to those values, and secret material does not belong in any file in this repository.

`account.hcl` is gitignored. After you fill it in, `git status` should not list that file, and a search of the tree should not find access keys or private keys:

```bash
git status
git grep -E 'AKIA[0-9A-Z]{16}|BEGIN (RSA |OPENSSH )?PRIVATE' -- ':!*.lock.hcl' || true
```

## Plan

From the account folder you are applying, the first plan creates that account's remote state bucket and validates every stack. Dev and prod are separate accounts, so run this once in each folder, with the profile that matches that folder's `account.hcl`:

```bash
cd aws-delphi-dev
terragrunt plan --backend-bootstrap --all

cd ../aws-delphi-prod
terragrunt plan --backend-bootstrap --all
```

`--backend-bootstrap` creates the encrypted state bucket declared in `root.hcl` when that bucket is missing. The name is `s3-delphi-<env>-ue1-<account_id>-terraform-state` in `us-east-1`, with the lock held by a lockfile in the same bucket. `--all` plans each stack under the account folder, which is how you confirm the configuration before any apply.

The Lambda before-hook runs during that plan and looks for its zip in the shared artifact bucket. Apply `us-east-1/s3-lambda-artifacts` once the state bucket exists, then plan again, if the Lambda unit stops because the bucket is not there yet. That bucket holds every Lambda zip in the account. Each function uses its own key, and the hook uploads a placeholder zip only when that key is missing. The plan role used by GitHub Actions cannot upload that object, so the placeholder has to exist before a runner plans the Lambda unit.

## Continuous integration

Pull requests plan, and only a merge to `main` applies. The plan that reviewers read is speculative: it is written as a pull request comment and is never the plan that gets applied, because a saved plan goes stale as soon as state or `main` moves, and because the plan file contains a copy of state. After the merge, `.github/workflows/terragrunt-apply.yml` plans again on a GitHub-hosted runner and applies that saved plan in the same job. Dev treats the merge as the approval. Prod uses the GitHub Environment named `prod`, so GitHub waits for the required reviewers and does not mint the OIDC token until they approve. A failed apply does not unmerge the pull request. Terraform keeps every resource that finished, and the recovery is to re-run the failed job or to dispatch the apply workflow again for the same commits. A later unrelated merge does not retry the failed units. The weekly drift workflow plans every unit with the plan role, opens an issue when the plan is not empty, and does not apply. Dispatching the apply workflow with reconcile set to true is how you apply that drift after you have read it.

The apply role trusts `repo:<repository>:environment:dev` or `environment:prod`, and it also requires `job_workflow_ref` to name `.github/workflows/terragrunt-apply.yml` on `refs/heads/main`. A pull request runs the workflow from the merge ref, so it cannot assume the role that writes to AWS even if the pull request edits the workflow. The plan role trusts `environment:dev-plan` or `environment:prod-plan` and is not pinned to `main`, because that pin would make every pull request plan fail. It can read the services this landscape uses and can write only the `.tflock` objects in the state bucket. It cannot write state and it cannot delete a bucket. The apply role can change the services the modules create, and it is denied IAM user creation, AWS Organizations, deletion of the state bucket, and any rewrite of these two roles. A change to the roles themselves is applied from the laptop profile, because the pipeline is not allowed to widen its own trust.

Someone who clones this repository into their own account still applies `github_oidc_provider`, `github_oidc_iac_plan`, and `github_oidc_iac_apply` once from a laptop, after the state bucket exists. Copy the role ARN from `terragrunt output role_arn` into the GitHub Environment variable `AWS_ROLE_TO_ASSUME`. The plan environments (`dev-plan`, `prod-plan`) receive the plan role ARN, and the apply environments (`dev`, `prod`) receive the apply role ARN. Each of those four environments also needs `AWS_ACCOUNT_ID`, `ROUTE53_ACCOUNT_ID`, `DNS_MANAGER_ROLE_ARN`, `APP_OIDC_SUBJECTS` (comma-separated, without the `repo:` prefix, matching `oidc_subjects`), `IAC_PLAN_OIDC_SUBJECT`, `IAC_APPLY_OIDC_SUBJECT`, and `IAC_APPLY_JOB_WORKFLOW_REF`. The workflow writes `account.hcl` from those variables at runtime and does not commit it. The `iac_*` strings in that file must be the full `sub` claim, including `repo:`. Repositories created after 15 July 2026, or opted into immutable subject claims, put the owner id and repository id in `sub`. A name-form subject on a repository that issues the id form will never assume the role, so confirm the claim before the first apply of the roles and put the same strings in the gitignored `account.hcl` and in the GitHub variables.

`dev-plan` and `prod-plan` have no required reviewers, because a pull request must be able to plan, and their deployment branches are not limited to `main`. `dev` and `prod` allow deployments only from `main`. `prod` has required reviewers. Branch protection on `main` requires the check named `Terragrunt plan`, which is the gate job in the plan workflow. Add the `allow-destroy` label when a plan destroys resources; without it the check fails. `.github/CODEOWNERS` ships with the production and workflow rules commented out. Uncomment them only after the names are real owners in the repository, and then require CODEOWNERS review. Do not enable workflows from forks. The DNS manager role, which lives in the account that owns the hosted zone, must trust both new role ARNs, or the `tls` and `dns_record` units fail when the runner tries to assume it. Tool versions are pinned in `.github/terraform-versions.env` and must keep satisfying the module constraint `~> 1.14.0`. The state bucket is still created with `--backend-bootstrap` from the laptop. The runners do not bootstrap the bucket they store state in.

## Run the application

The application is easyCMDB. Its technical alias, `argus`, is what the stacks, resource names, and Postgres schema here use. Clone this repository, `argus-api-lambda`, and [`easycmdb-web`](https://github.com/karlamber/easycmdb-web) as sibling directories. This repository creates the account resources. The other two build the software and publish it onto those resources. Plan and apply the stacks here first, including `us-east-1/s3-lambda-artifacts`, the Argus Lambda, API Gateway, Cognito, and CloudFront. Seed the Aurora password for the `argus_lambda` user outside Terraform and apply `us-east-1/argus/rds/initial-config.sql` before the API is expected to read or write data.

Publish the API next. From `argus-api-lambda`, `npm run deploy:poc` builds `bundle.zip`, uploads it to `s3-delphi-dev-ue1-<account_id>-lambda-artifacts` at `argus/dev/argus-argus_api.zip`, and calls `lambda:UpdateFunctionCode` on `lambda-argus-dev-ue1-argus_api`. The Deploy section of that repository's README covers the `.env.deploy.local` file the script reads. Set `POC_LAMBDA_ARTIFACT_KEY` to `argus/dev/argus-argus_api.zip`, because the example file's default key is not the key this Lambda reads. That replaces the placeholder object the Lambda before-hook uploaded.

Publish the SPA last. From `easycmdb-web`, `npm run deploy:poc` (see the Deploy section of that repository's README) syncs `dist/` to `s3-argus-dev-ue1-<account_id>-cf-origin` and invalidates the distribution. The browser calls `/api` on the same host, and CloudFront forwards `/api/*` to API Gateway. Hosted-UI sign-in uses `https://argus-dev.example.net` because that hostname is the Cognito callback registered for the `argus` app client. The CloudFront domain name from `terragrunt output cloudfront_distribution_domain_name` serves the files as soon as the invalidation finishes. The alias answers after the DNS stack has written the record. Prod uses the same publish steps with `prod` in the names: `s3-delphi-prod-ue1-<account_id>-lambda-artifacts`, `argus/prod/argus-argus_api.zip`, `lambda-argus-prod-ue1-argus_api`, `s3-argus-prod-ue1-<account_id>-cf-origin`, and `https://argus-prod.example.net`.

## Promotion

Promote by planning `dev`, then `tst`, then `prod`, with each stack planned on its own. This repository contains the `dev` and `prod` account folders. There is no `tst` folder yet.

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
