# DevSecOps controls for easyCMDB

The pull-request checks live in git. The account controls are written in the `aws-delphi-dev` stacks and apply when that account is provisioned. A pull request cannot merge a leaked secret, a known high vulnerability in a production dependency, or a new Terraform misconfiguration without a failing check. Deploys use a GitHub OIDC role. There are no long-lived cloud keys in the pipeline.

This is not a SOC, and it is not a FedRAMP package. Detective review is a Prowler run I start by hand.

Cost of every control below is $0. Customer-managed KMS keys, AWS WAF, GuardDuty, Security Hub, AWS Config, Inspector, and Macie are not used.

## Controls

| Control | Where it is enforced | How to verify |
|---|---|---|
| Secret scanning | `easycmdb-api`, `easycmdb-web`, and `aws-delphi` workflow job **Secret scan** (gitleaks) | A pull request that adds a key fails the job. |
| Production dependency scan | App workflow job **Dependency scan** (Trivy) | Fails on a high or critical production advisory that already has a fix. |
| Terraform policy | `aws-delphi` job **Checkov**, compared with `.checkov.baseline` | A finding that is not in the baseline fails the job. |
| Terraform misconfiguration | `aws-delphi` job **Trivy config**, exceptions in `.trivyignore.yaml` | A new high or critical finding fails the job. Each ignore line states why. |
| Workflow syntax | `aws-delphi` job **Workflow lint** | `actionlint` fails the job. |
| Dependency updates | `.github/dependabot.yml` in each repo | Minor and patch updates arrive as one pull request. Majors stay separate. |
| Keyless deploy | `tf-modules/tf-github-oidc-role` | The app deploy role can update the Lambda and the SPA bucket. It cannot administer the account. |
| Read-only audit role | Dev stack `github_oidc_readonly` | Trusts only `karlamber/aws-delphi` on `main`. Attached policy is AWS `SecurityAudit`. |
| Account access findings | Dev stack `access_analyzer` | External-access analyzer in `us-east-1`. |
| Encryption at rest | Aurora uses the AWS-managed key. S3 and the CloudTrail bucket use SSE-S3. | No customer-managed KMS key. |
| Private data tier | Aurora subnets are isolated. | No route to the internet from that tier. |
| Trail integrity | `aws_cloudtrail.main` has `enable_log_file_validation` | One management-event trail. No data events. |
| Trail retention | CloudTrail bucket lifecycle, 365 days | Public access is blocked. `force_destroy` is false. |
| Edge headers | `aws_cloudfront_response_headers_policy.security` | HSTS, nosniff, frame deny, referrer policy. |
| No paid WAF | `enable_default_waf = false` on dev and prod CloudFront | A later apply does not create a web ACL. |
| App authentication | Dev Lambda `AUTH_MODE = cognito` | Basic auth remains for local runs. |
| Change audit | `easycmdb-api` log line `audit.mutation` | A successful write logs who changed what. |
| Optional MFA | Dev Cognito `mfa_configuration = OPTIONAL` | Software-token MFA. Password sign-in still works until a user enrolls. |
| Point-in-time account review | Workflow **Prowler**, started with `workflow_dispatch` | Assumes only the read-only role. The HTML report is the artifact. |

## What I will not say

I do not run continuous detection. Prowler does not page anyone. I have not turned on GuardDuty, Security Hub, or AWS Config.

I do not own a FedRAMP authorization, and I do not claim the dev account meets a compliance regime.

The Checkov baseline and the Trivy ignore file are accepted gaps, not a clean scan. Public subnet addresses and outbound internet on the public and private tiers are the VPC design. Customer-managed KMS keys are a paid service, so encryption here is SSE-S3 or an AWS-managed key.

## Commands

From `aws-delphi`, the same checks the pull-request jobs run:

```bash
checkov -d tf-modules --framework terraform --download-external-modules false --compact --baseline .checkov.baseline
trivy config --severity HIGH,CRITICAL --exit-code 1 --ignorefile .trivyignore.yaml --tf-exclude-downloaded-modules .
```

After the dev read-only role exists, start **Prowler** from the Actions tab on `main`. Paste the `iam_role_arn` output from `github_oidc_readonly`. Do not paste the deploy role. The workflow rejects any other role name.

Some Prowler checks need more than `SecurityAudit` and will be skipped. Those checks are not fixed by adding write access.
