# aws-delphi — Delphi landscape (Terragrunt + Terraform)

This repo is one of **three** implementations of the same Argus CMDB infrastructure on AWS. All three create the same kinds of resources (VPC, Cognito, Lambda, API Gateway, CloudFront, DNS, and so on). What differs is **how you run the stacks**:

| Repo | Method | Link |
|---|---|---|
| **`aws-delphi`** (this repo) | Terragrunt wraps Terraform | — |
| `aws-kos` | Python orchestrator runs Terraform | [karlamber/aws-kos](https://github.com/karlamber/aws-kos) |
| `aws-delos` | Plain Terraform only (no wrapper) | [karlamber/aws-delos](https://github.com/karlamber/aws-delos) |

Use this repo to see a Terragrunt-driven layout. Compare with Kos or Delos if you want the same infrastructure without Terragrunt.

Hostnames in this lab use the **fifty9** domain (for example `argus-dev.fifty9.net`). Public DNS for `fifty9.net` and the cross-account DNS role live in the management shared-services account — not in this repo.

Real account IDs and OIDC subjects stay in a gitignored `account.hcl`. Committed files use placeholders.

---

## How the three implementations differ

| | Delphi (this repo) | Kos | Delos |
|---|---|---|---|
| What runs the stacks | Terragrunt | Python (`orchestrator/`) | You + Terraform CLI |
| Shared account settings | `account.hcl` + `root.hcl` | `account.json` + `region.json` | `environments/<env>/terraform.tfvars` |
| Which stack runs when | `dependency` / `dependencies` in each stack’s HCL | `stacks.json` | Documented apply order (and optional `scripts/tf-stack.sh`) |
| How one stack reads another’s outputs | Terragrunt `dependency.x.outputs` | `data.terraform_remote_state` | `data.terraform_remote_state` |
| Layout | `aws-delphi-{env}/us-east-1/…` | `aws-kos-{env}/us-east-1/…` | `live/<env>/us-east-1/…` |

Do not run Delphi until the `aws-delphi-dev` AWS account exists and you have filled in local secret/config values (see [Before first apply](#before-first-apply)).

---

## How it works

Each stack folder is thin: a `terragrunt.hcl` that points at a module and sets stack-specific inputs. Terragrunt fills in the rest at plan/apply time:

1. Walk up to `account.hcl`, `region.hcl`, and `root.hcl`
2. Generate the AWS provider and remote-state backend
3. Merge shared inputs (account ID, region, landscape, …) into every stack
4. Resolve `dependency` blocks (with mock outputs so `plan` can run before parents exist)
5. Run Terraform in that folder

Terraform still creates and changes AWS resources. Terragrunt handles shared config, backends, and wiring between stacks.

### What you edit

| File | Purpose |
|---|---|
| `aws-delphi-dev/account.hcl` or `aws-delphi-prod/account.hcl` (gitignored; copy from `account.hcl.example`) | Shared values: AWS account ID, DNS role, GitHub OIDC subjects, artifact bucket |
| `aws-delphi-*/us-east-1/region.hcl` | AWS region |
| `root.hcl` | Provider generation, state backend, shared input merge |
| Each stack’s `terragrunt.hcl` | Module source, dependencies, stack-specific inputs (VPC CIDRs, Cognito URLs, Lambda env, …) |
| Modules under `tf-modules/` | Reusable Terraform for this landscape |

You do **not** hand-copy the account ID into every stack — Terragrunt merges it from `account.hcl`.

### Dependencies between stacks

Two Terragrunt patterns appear in this repo:

| Kind | HCL | Meaning |
|---|---|---|
| Order-only | `dependencies { paths = [...] }` | “Run this stack after that one” (no outputs read) |
| Output wiring | `dependency "vpc" { … }` + `dependency.vpc.outputs.…` | This stack needs values from another stack’s state |

Terragrunt can `plan` stacks that use `dependency` before parents are applied by using `mock_outputs`. For a real apply, apply dependency stacks first (or use a tool that walks the graph). Prefer one stack at a time in this repo.

---

## Same stack, three ways (example: `vpc`)

| | Delphi (this repo) | Kos | Delos |
|---|---|---|---|
| Where you edit stack settings | `vpc/terragrunt.hcl` | `vpc/main.tf` | `live/<env>/…/vpc/main.tf` |
| Where the shared account ID comes from | Parent `account.hcl` (merged by Terragrunt) | `account.json` → written into tfvars by Python | `environments/<env>/terraform.tfvars` via `-var-file` |
| How you run it | `terragrunt plan` in the stack folder | `python3 -m orchestrator plan vpc` | `terraform plan -var-file=…` (or `./scripts/tf-stack.sh … plan`) |

Reusable modules live under `tf-modules/`. The application name is still **argus**.

---

## Layout

```text
aws-delphi/
├── root.hcl                    # shared provider, backend, and inputs
├── tf-modules/                 # shared Terraform modules for this landscape
├── aws-delphi-dev/             # member account folder (env=dev)
│   ├── account.hcl.example     # committed placeholders (safe to publish)
│   ├── account.hcl             # gitignored — your real account IDs and OIDC subjects
│   └── us-east-1/
│       ├── region.hcl
│       ├── vpc, cognito, cloudwatch_logging, github_oidc_*
│       └── argus/              # rds, lambda, apigw, tls, cloudfront, dns, ssm, iam
└── aws-delphi-prod/            # member account folder (env=prod) — same stack layout
    ├── account.hcl.example
    └── us-east-1/…
```

Each stack folder contains a `terragrunt.hcl`. Terragrunt generates provider/backend files into that folder at run time.

---

## Commands

```bash
cd ~/Projects/aws-delphi

# Plan / apply one stack at a time (recommended)
cd aws-delphi-dev/us-east-1/cloudwatch_logging
terragrunt plan
terragrunt apply

cd ../vpc
terragrunt plan
terragrunt apply
```

Always `cd` into the folder that contains `terragrunt.hcl`. Confirm the AWS profile matches `account.hcl` before you apply.

### Promotion order

`dev` → `tst` → `prod`. Use the matching account folder (`aws-delphi-dev`, then `aws-delphi-prod`). Plan each stack independently; do not skip environments.

---

## Before first apply

1. Create the AWS account from the account-factory repo (`aws-delphi-dev` applied).
2. Create your local config (never commit this file):
   ```bash
   cp aws-delphi-dev/account.hcl.example aws-delphi-dev/account.hcl
   # set account_id, route53_account_id, dns_manager_role_arn,
   # artifact_bucket, oidc_subjects
   ```
3. If this environment needs DNS or shared Lambda artifacts, grant the member account access in the management shared-services account (`route53-dnsmgr`, shared Lambda bucket).
4. For the Lambda artifact copy hook, export `ARTIFACT_AWS_PROFILE` set to a profile that can read the shared artifact bucket. Sign in and confirm you are in the right account:
   ```bash
   aws sso login --profile aws-delphi-dev
   aws sts get-caller-identity --profile aws-delphi-dev
   ```
5. Create the S3 bucket that stores Terraform state (once per account/region), matching `root.hcl`:
   ```bash
   aws --profile aws-delphi-dev s3 mb s3://s3-delphi-dev-ue1-terraform-state --region us-east-1
   ```
6. Put secrets into SSM Parameter Store yourself (SecureString). Do not put real passwords in Terragrunt/HCL or git. The `argus/ssm_param` stack uses a placeholder (`<SEED_OUTSIDE_TERRAFORM>`); seed the live value outside Terraform — the module ignores value drift.
7. Plan and apply one stack at a time, starting with stacks that have no dependencies (for example `cloudwatch_logging`, then `vpc`, then Argus stacks).
8. After the RDS stack exists, bootstrap Argus schema: run
   `aws-delphi-dev/us-east-1/argus/rds/initial-config.sql` as `postgres` (RDS Query
   Editor). Then set `argus_lambda` password to match Lambda `PGPASSWORD`. Later
   schema changes live in [easycmdb-api](https://github.com/karlamber/easycmdb-api) — see [Argus database schema](#argus-database-schema).

---

## What belongs in git vs what stays local

| Safe to commit | Keep local (gitignored) |
|---|---|
| `account.hcl.example` with placeholder IDs | `account.hcl` with real account IDs, DNS role ARN, OIDC subjects, artifact bucket |
| Stack `terragrunt.hcl` without hardcoded GitHub org/repo node IDs | `.terragrunt-cache/`, `.terraform/`, state files |
| Modules, `root.hcl`, README | `.env*` |

Before you push (especially before making the repo public):

```bash
git status
# confirm account.hcl is NOT listed
git grep -E 'AKIA[0-9A-Z]{16}|BEGIN (RSA |OPENSSH )?PRIVATE' -- ':!*.lock.hcl' || true
```

Do not commit real AWS account IDs, GitHub OIDC subject IDs, or database/SSM passwords.

---

## Related application repos

The product name is easyCMDB. The infrastructure alias stays `argus`.

| Repo | Purpose |
|---|---|
| [easycmdb-web](https://github.com/karlamber/easycmdb-web) | React SPA |
| [easycmdb-api](https://github.com/karlamber/easycmdb-api) | TypeScript Lambda API |

## Argus database schema

RDS Terraform creates an empty Aurora PostgreSQL database (`argus`). It does
**not** create tables. Schema is owned by [easycmdb-api](https://github.com/karlamber/easycmdb-api) and applied in two
ways:

| When | What to run |
|---|---|
| Brand-new cluster | `us-east-1/argus/rds/initial-config.sql` as master user `postgres` (RDS Query Editor). Then set `argus_lambda` password to match Lambda `PGPASSWORD`. |
| Cluster that already has tables | Do **not** re-run `initial-config.sql` expecting ALTERs — it will not change existing tables. Apply `easycmdb-api/db/migrations/` (`npm run migrate`, or paste the new file in Query Editor and stamp `argus.schema_migrations`). |

Apply SQL on the **target** environment **before** deploying Lambda code that
needs the new shape. Keep the `dev` and `prod` copies of `initial-config.sql` in
lockstep; after each migration, paste `npm run migrate:stamps` from
`easycmdb-api` into the `schema_migrations` INSERT.

Promotion: apply schema in `dev`, then `prod`. Same order as application
deploys. Never skip.

---

## Network

Each env account gets its own `/20` (no CIDR overlap between dev and prod):

| Account folder | Account block | us-east-1 VPC | Set in |
|---|---|---|---|
| `aws-delphi-dev` | `10.0.0.0/20` | `10.0.0.0/21` | `aws-delphi-dev/us-east-1/vpc/terragrunt.hcl` |
| `aws-delphi-prod` | `10.0.48.0/20` | `10.0.48.0/21` | `aws-delphi-prod/us-east-1/vpc/terragrunt.hcl` |

These blocks do not overlap Kos (`10.0.16.0/20` dev, `10.0.64.0/20` prod) or Delos (`10.0.32.0/20` dev, `10.0.80.0/20` prod).
AWS stays in `10.0.0.0/11`; Azure VNets use `10.32.0.0/11`.
