# aws-delphi — Delphi landscape (Argus CMDB)

Terragrunt monorepo for the **delphi** landscape. Workloads run in member account(s) such as `aws-delphi-dev` (vended from a separate account-factory repo).

Lab brand: **fifty9**. Public DNS (`fifty9.net`) and cross-account DNS IAM live in the mgmt shared-services account.

Intended as a portfolio IaC sample: **private first, public later**. Real account IDs and OIDC subjects stay in a gitignored `account.hcl`.

## Repo layers (fifty9 AWS)

| Folder | Role |
|--------|------|
| Account factory repo (`aws/`) | Creates `aws-delphi-dev` |
| Mgmt shared services (`59madison/`) | Route53, OIDC, shared S3 |
| **`aws-delphi/`** (this repo) | Landscape stacks inside the member account |

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
        └── argus/
```

## Publishing / local secrets

| Committed (safe) | Local only (gitignored) |
|---|---|
| `account.hcl.example` with `000000000000` placeholders | `account.hcl` with real account IDs, DNS role ARN, OIDC subjects, artifact bucket |
| Stack `terragrunt.hcl` without hardcoded GitHub node IDs | `.terragrunt-cache/`, `.terraform/`, state files |
| Modules + README | `.env*` |

Bootstrap local config:

```bash
cp aws-delphi-dev/account.hcl.example aws-delphi-dev/account.hcl
# edit account.hcl: account_id, route53_*, artifact_bucket, oidc_subjects
```

**Important:** A real SSM SecureString placeholder was removed from `argus/ssm_param` (`<SEED_OUTSIDE_TERRAFORM>`). Seed the live parameter outside Terraform; the module ignores value drift.

Before push / before making the repo public:

```bash
git status   # account.hcl must NOT appear
git grep -E 'AKIA[0-9A-Z]{16}|BEGIN (RSA |OPENSSH )?PRIVATE' -- ':!*.lock.hcl' || true
```

## Related repos

| Repo | Purpose |
|------|---------|
| Account factory | Vend / OU for this account |
| Mgmt shared services | fifty9.net DNS trusts |
| `argus-front-end` | Vue SPA |
| `argus-api-lambda` | Node.js API |

## Before first apply

1. Account exists under the account factory (`aws-delphi-dev` applied).
2. `cp account.hcl.example account.hcl` and fill real values; SSO profile `aws-delphi-dev`.
3. `aws sso login --profile aws-delphi-dev` then `aws sts get-caller-identity --profile aws-delphi-dev`.
4. Seed secrets outside Terraform (SSM SecureString) — never commit secrets to HCL.
5. Grant the member account in mgmt (`route53-dnsmgr` / shared Lambda bucket) if needed.
6. Plan/apply one stack at a time (`cd` into the folder with `terragrunt.hcl`).

## Promotion order

`dev` → `tst` → `prod`. Plan each stack independently.

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

Day-2: branch `PRDV-{number}-…`, commit `PRDV-{number}: …`, open a PR with `gh pr create`.
