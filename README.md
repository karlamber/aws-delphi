# aws-delphi — Delphi landscape (Terragrunt + Terraform)

This repo builds the Argus app infrastructure in AWS using **Terragrunt** to drive Terraform stacks. Workloads run in a member account such as `aws-delphi-dev` (created from a separate account-factory repo).

Hostnames in this lab use the **fifty9** domain (for example `argus-dev.fifty9.net`). Public DNS for `fifty9.net` and the cross-account DNS role live in the management shared-services account — not in this repo.

The repo is meant as a learnable / portfolio example of multi-stack AWS infrastructure — keep it private while it contains real account details; publish later only after placeholders and gitignore are solid. Real account IDs and OIDC subjects stay in a gitignored `account.hcl`.

Sibling landscapes that build the same Argus stacks with different glue:

| Repo | How stacks are run |
|---|---|
| **`aws-delphi`** (this repo) | Terragrunt |
| [`aws-kos`](../aws-kos) | Python orchestrator + Terraform |
| [`aws-delos`](../aws-delos) | Plain Terraform only (`live/<env>/…`) |

---

## Delphi vs Kos

| | Delphi (`aws-delphi`) | Kos (`aws-kos`) |
|---|---|---|
| What runs the stacks | Terragrunt | Python (`orchestrator/`) |
| Shared account settings | `account.hcl` + `root.hcl` | `account.json` + `region.json` |
| Which stack runs when | `dependency` / `dependencies` in each stack’s HCL | `stacks.json` |
| How one stack reads another’s outputs | Terragrunt `dependency.x.outputs` | Terraform `data.terraform_remote_state` |

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

## Compared to Kos (one stack)

Example: the `vpc` stack

| | Delphi | Kos |
|---|---|---|
| Where you edit stack settings | `vpc/terragrunt.hcl` | `vpc/main.tf` |
| Where the shared account ID comes from | Parent `account.hcl` (merged by Terragrunt) | `account.json` → written into tfvars by Python |
| How you run it | `terragrunt plan` in the stack folder | `python3 -m orchestrator plan vpc` |

Reusable modules live under `tf-modules/` in both repos. The application name is still **argus**.

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
4. Sign in and confirm you are in the right account:
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

| Repo | Purpose |
|---|---|
| `argus-front-end` | Vue SPA |
| `argus-api-lambda` | Node.js API |

---

## Network

Each env account gets its own `/20` (no CIDR overlap between dev and prod):

| Account folder | Account block | us-east-1 VPC | Set in |
|---|---|---|---|
| `aws-delphi-dev` | `10.0.0.0/20` | `10.0.0.0/21` | `aws-delphi-dev/us-east-1/vpc/terragrunt.hcl` |
| `aws-delphi-prod` | `10.0.48.0/20` | `10.0.48.0/21` | `aws-delphi-prod/us-east-1/vpc/terragrunt.hcl` |

These blocks do not overlap Kos (`10.0.16.0/20` dev, `10.0.64.0/20` prod) or Delos (`10.0.32.0/20` dev, `10.0.80.0/20` prod).
