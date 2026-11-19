locals {
  is_plan = var.mode == "plan"
  protected_role_arns = [
    for name in var.protected_role_names :
    "arn:aws:iam::${var.account_id}:role/${name}"
  ]
  state_bucket_arn = "arn:aws:s3:::${var.state_bucket_name}"
}

data "aws_iam_policy_document" "trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = [var.oidc_subject]
    }

    dynamic "condition" {
      for_each = var.job_workflow_ref == "" ? [] : [var.job_workflow_ref]
      content {
        test     = "StringEquals"
        variable = "token.actions.githubusercontent.com:job_workflow_ref"
        values   = [condition.value]
      }
    }
  }
}

data "aws_iam_policy_document" "plan" {
  count = local.is_plan ? 1 : 0

  statement {
    sid    = "ReadLandscape"
    effect = "Allow"
    actions = [
      "acm:Describe*",
      "acm:Get*",
      "acm:List*",
      "apigateway:GET",
      "cloudfront:Describe*",
      "cloudfront:Get*",
      "cloudfront:List*",
      "cloudtrail:Describe*",
      "cloudtrail:Get*",
      "cloudtrail:List*",
      "cloudtrail:LookupEvents",
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*",
      "cognito-idp:Describe*",
      "cognito-idp:Get*",
      "cognito-idp:List*",
      "ec2:Describe*",
      "ec2:Get*",
      "ec2:List*",
      "iam:Get*",
      "iam:List*",
      "kms:Describe*",
      "kms:Get*",
      "kms:List*",
      "lambda:Get*",
      "lambda:List*",
      "logs:Describe*",
      "logs:FilterLogEvents",
      "logs:Get*",
      "logs:List*",
      "logs:StartQuery",
      "logs:StopQuery",
      "rds:Describe*",
      "rds:List*",
      "tag:Get*",
      "wafv2:CheckCapacity",
      "wafv2:Describe*",
      "wafv2:Get*",
      "wafv2:List*",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "ReadBuckets"
    effect = "Allow"
    actions = [
      "s3:Get*",
      "s3:List*",
    ]
    resources = ["*"]
  }

  # The lock object is the state key plus ".tflock", and state keys contain
  # slashes. The * in an S3 object ARN matches across those slashes, so this
  # resource is every key in the bucket that ends in tflock and no other object.
  statement {
    sid    = "WriteStateLocks"
    effect = "Allow"
    actions = [
      "s3:DeleteObject",
      "s3:PutObject",
    ]
    resources = ["${local.state_bucket_arn}/*tflock"]
  }

  statement {
    sid       = "DenyBucketDelete"
    effect    = "Deny"
    actions   = ["s3:DeleteBucket"]
    resources = ["*"]
  }

  statement {
    sid       = "AssumeDnsRole"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [var.dns_manager_role_arn]
  }
}

data "aws_iam_policy_document" "apply" {
  count = local.is_plan ? 0 : 1

  statement {
    sid    = "ManageLandscape"
    effect = "Allow"
    actions = [
      "acm:*",
      "apigateway:*",
      "cloudfront:*",
      "cloudtrail:*",
      "cloudwatch:*",
      "cognito-idp:*",
      "ec2:*",
      "iam:*",
      "kms:*",
      "lambda:*",
      "logs:*",
      "rds:*",
      "s3:*",
      "tag:*",
      "wafv2:*",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "AssumeDnsRole"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [var.dns_manager_role_arn]
  }

  statement {
    sid       = "DenyStateBucketDelete"
    effect    = "Deny"
    actions   = ["s3:DeleteBucket"]
    resources = [local.state_bucket_arn]
  }

  statement {
    sid       = "DenyIamUsersAndOrganizations"
    effect    = "Deny"
    actions   = ["iam:CreateUser", "organizations:*"]
    resources = ["*"]
  }

  statement {
    sid    = "DenyRewritingIacRoles"
    effect = "Deny"
    actions = [
      "iam:AttachRolePolicy",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:UpdateAssumeRolePolicy",
    ]
    resources = local.protected_role_arns
  }
}

resource "aws_iam_role" "this" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json
  description        = "GitHub Actions Terragrunt ${var.mode} role for ${var.landscape} ${var.env}."

  tags = {
    Name = var.role_name
  }
}

resource "aws_iam_role_policy" "this" {
  name   = "policy-${var.role_name}"
  role   = aws_iam_role.this.id
  policy = local.is_plan ? data.aws_iam_policy_document.plan[0].json : data.aws_iam_policy_document.apply[0].json
}
