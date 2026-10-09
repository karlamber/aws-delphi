module "github_oidc_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-github-oidc-role"
  version = "5.60.0"

  name        = "role-${var.landscape}-${var.env}-${var.region_short}-github_oidc"
  description = "GitHub Actions deploy role for easyCMDB. Updates the API Lambda and syncs the SPA origin."
  subjects    = var.oidc_subjects
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid = "UpdateApiFunctionCode"
    actions = [
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "lambda:UpdateFunctionCode",
      "lambda:PublishVersion",
    ]
    resources = [
      "arn:aws:lambda:${var.region}:${var.account_id}:function:lambda-argus-${var.env}-${var.region_short}-*",
    ]
  }

  statement {
    sid = "ReadLambdaArtifact"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]
    resources = [
      "arn:aws:s3:::${var.artifact_bucket}/argus/*",
    ]
  }

  statement {
    sid       = "ListLambdaArtifact"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.artifact_bucket}"]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["argus/*"]
    }
  }

  statement {
    sid = "ListSpaOrigin"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    resources = [
      "arn:aws:s3:::s3-argus-${var.env}-${var.region_short}-cf-origin",
    ]
  }

  statement {
    sid = "SyncSpaOrigin"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:AbortMultipartUpload",
    ]
    resources = [
      "arn:aws:s3:::s3-argus-${var.env}-${var.region_short}-cf-origin/*",
    ]
  }

  statement {
    sid = "InvalidateDistribution"
    actions = [
      "cloudfront:CreateInvalidation",
      "cloudfront:GetInvalidation",
      "cloudfront:ListInvalidations",
    ]
    resources = [
      "arn:aws:cloudfront::${var.account_id}:distribution/*",
    ]
  }

  # ListDistributions has no resource-level permission. The SPA deploy uses it
  # only when resolving a distribution id from a domain name.
  statement {
    sid       = "ResolveDistributionId"
    actions   = ["cloudfront:ListDistributions"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "policy-${var.landscape}-${var.env}-${var.region_short}-github_oidc_deploy"
  role   = module.github_oidc_role.name
  policy = data.aws_iam_policy_document.deploy.json
}
