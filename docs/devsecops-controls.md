# DevSecOps controls for easyCMDB

The claim I can defend is the delivery path. A pull request fails when it leaks a secret, ships a known high or critical vulnerability in a production dependency, or adds a new Terraform misconfiguration. Deploys into AWS use a GitHub OIDC role, so the pipeline holds no long-lived access key. The account controls are written in the `aws-delphi-dev` stacks and take effect when that account is provisioned and the stacks are applied.

Every control on this page is free. Customer-managed KMS keys, AWS WAF, GuardDuty, Security Hub, AWS Config, Inspector, and Macie are left out because they cost money.

## What a pull request has to pass

`easycmdb-api`, `easycmdb-web`, and `aws-delphi` each run a **Secret scan** job with gitleaks. A pull request that adds a key fails that job.

The two app repositories also run a **Dependency scan** job with Trivy. It looks at production dependencies. It fails when a high or critical advisory already has a fix. Findings that only affect development tools stay in `npm audit` and do not block the merge.

`aws-delphi` adds the Terraform checks. **Checkov** scans `tf-modules` and compares the result with `.checkov.baseline`. A finding already in the baseline is an accepted gap. A finding that is new fails the job. **Trivy config** then looks for high and critical misconfigurations. Exceptions live in `.trivyignore.yaml`, and each line says why it is there. The same workflow runs **Workflow lint** with `actionlint`, so a broken workflow file fails before anyone relies on it.

Dependabot is configured in each repository. Minor and patch updates arrive together as one pull request. A major upgrade stays on its own pull request so it can be tested on that branch before it merges.

## How a deploy gets into the account

The app deploy role is `tf-modules/tf-github-oidc-role`. GitHub assumes it with OIDC. That role can update the Lambda and the SPA bucket, and it stops there. It is not an administrator role.

A second role lives in the dev stack `github_oidc_readonly`. It trusts only `karlamber/aws-delphi` on `main`, and the only policy attached to it is the AWS managed `SecurityAudit` policy. That role exists so a manual Prowler run can read the account. The apps do not deploy with it.

## What the dev account is built to do

These controls are in the Terraform. They are live after `aws-delphi-dev` exists and the stacks have been applied.

Aurora uses the AWS-managed encryption key. S3 and the CloudTrail bucket use SSE-S3. The database sits on isolated subnets, and that tier has no route to the internet.

There is one CloudTrail trail, and it records management events. Log file validation is on, so the trail can show whether a log file changed after AWS delivered it. The bucket keeps objects for 365 days, blocks public access, and has `force_destroy` set to false. Data events stay off because that trail feature is paid.

CloudFront attaches a security-headers policy: HSTS, `nosniff`, frame deny, and a referrer policy. `enable_default_waf` is false on the dev and prod distributions, so an apply leaves the paid web ACL out. The headers policy is the free control at the edge.

The deployed API uses Cognito (`AUTH_MODE = cognito`). Basic auth stays available for local runs. A successful write logs an `audit.mutation` line that records who changed what. Dev Cognito offers optional software-token MFA, so a user can enroll an authenticator app and a password-only user can still sign in. Prod does not set that input, so a prod apply leaves the pool unchanged.

IAM Access Analyzer is the dev stack `access_analyzer`. It creates an external-access analyzer in `us-east-1`, which reports when a resource is shared outside the account.

## Reviewing the account after it exists

Prowler is a workflow I start by hand from the Actions tab on `main`, once the read-only role exists. I paste the `iam_role_arn` output from `github_oidc_readonly`. The workflow accepts only the role named `role-delphi-dev-ue1-github_oidc_readonly`, so the deploy role cannot be used for the scan. The HTML report is saved as a workflow artifact.

Some Prowler checks need more permission than `SecurityAudit` and show up as skipped. Those skips stay skipped. The read-only role does not get write access to make the report look fuller.

## What the claim covers

This is preventive control in git, a keyless deploy, and a point-in-time read of the account when I choose to run one. A security operations center, a FedRAMP authorization, and always-on detection are a larger scope than this work. Prowler runs when I start it, and it does not page anyone.

The Checkov baseline and the Trivy ignore file are the accepted gaps. Public addresses on the public subnets, and outbound internet from the public and private tiers, are the VPC design. Encryption is SSE-S3 or an AWS-managed key.

## Running the same checks locally

From `aws-delphi`, these are the Terraform checks the pull-request jobs run:

```bash
checkov -d tf-modules --framework terraform --download-external-modules false --compact --baseline .checkov.baseline
trivy config --severity HIGH,CRITICAL --exit-code 1 --ignorefile .trivyignore.yaml --tf-exclude-downloaded-modules .
```
