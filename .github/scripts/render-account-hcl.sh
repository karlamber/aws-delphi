#!/usr/bin/env bash
# Write a gitignored account.hcl for one account folder from GitHub Environment
# variables. The file is never committed. Values that contain a double quote
# or a newline are rejected so they cannot break out of the HCL strings.
set -euo pipefail

account_dir="${1:?account directory, for example aws-delphi-dev}"

: "${ACCOUNT_ENV:?Set ACCOUNT_ENV to dev or prod.}"
: "${AWS_ACCOUNT_ID:?Set AWS_ACCOUNT_ID on this GitHub Environment. See the Continuous integration section of the README.}"
: "${ROUTE53_ACCOUNT_ID:?Set ROUTE53_ACCOUNT_ID on this GitHub Environment.}"
: "${DNS_MANAGER_ROLE_ARN:?Set DNS_MANAGER_ROLE_ARN on this GitHub Environment.}"
: "${APP_OIDC_SUBJECTS:?Set APP_OIDC_SUBJECTS on this GitHub Environment to a comma-separated list of app-deploy OIDC subjects, without the repo: prefix.}"
: "${IAC_PLAN_OIDC_SUBJECT:?Set IAC_PLAN_OIDC_SUBJECT on this GitHub Environment to the full plan sub claim, including the repo: prefix.}"
: "${IAC_APPLY_OIDC_SUBJECT:?Set IAC_APPLY_OIDC_SUBJECT on this GitHub Environment to the full apply sub claim, including the repo: prefix.}"
: "${IAC_APPLY_JOB_WORKFLOW_REF:?Set IAC_APPLY_JOB_WORKFLOW_REF on this GitHub Environment.}"

python3 - "$account_dir" <<'PY'
import os
import pathlib
import sys

account_dir = pathlib.Path(sys.argv[1])
env = os.environ["ACCOUNT_ENV"]
if env not in ("dev", "prod"):
    raise SystemExit("ACCOUNT_ENV must be dev or prod. Rename the workflow matrix if the account folder is not aws-delphi-dev or aws-delphi-prod.")

def hcl(value: str) -> str:
    if '"' in value or "\n" in value or "\r" in value:
        raise SystemExit("A GitHub Environment variable contains a quote or newline. Remove it and set the value again.")
    return '"' + value + '"'

subjects = [part.strip() for part in os.environ["APP_OIDC_SUBJECTS"].split(",") if part.strip()]
if not subjects:
    raise SystemExit("APP_OIDC_SUBJECTS did not contain any subjects.")

subject_lines = "\n".join(f"    {hcl(subject)}," for subject in subjects)
body = f"""locals {{
  env          = {hcl(env)}
  account_name = {hcl("aws-delphi-" + env)}
  account_id   = {hcl(os.environ["AWS_ACCOUNT_ID"])}
  aws_profile  = ""
  landscape    = "delphi"

  route53_account_id   = {hcl(os.environ["ROUTE53_ACCOUNT_ID"])}
  dns_manager_role_arn = {hcl(os.environ["DNS_MANAGER_ROLE_ARN"])}

  oidc_subjects = [
{subject_lines}
  ]

  iac_plan_oidc_subject      = {hcl(os.environ["IAC_PLAN_OIDC_SUBJECT"])}
  iac_apply_oidc_subject     = {hcl(os.environ["IAC_APPLY_OIDC_SUBJECT"])}
  iac_apply_job_workflow_ref = {hcl(os.environ["IAC_APPLY_JOB_WORKFLOW_REF"])}
}}
"""
target = account_dir / "account.hcl"
target.write_text(body)
print(f"Wrote {target} for {env}. The file is gitignored.")
PY
