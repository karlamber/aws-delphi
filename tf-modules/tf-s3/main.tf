locals {
  base_name = join("-", [var.landscape, var.env, var.region_short])
}

resource "aws_s3_bucket" "bucket" {
  bucket = "s3-${var.app_alias}-${var.env}-${var.region_short}-${var.detail}"
  tags = {
    App_Alias = var.app_alias
    Name      = "s3-${var.app_alias}-${var.env}-${var.region_short}-${var.detail}"
  }
}

resource "aws_s3_bucket_versioning" "versioning" {
  count  = var.versioning_enabled ? 1 : 0
  bucket = aws_s3_bucket.bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  count  = var.encryption_enabled ? 1 : 0
  bucket = aws_s3_bucket.bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lifecycle" {
  count = (
    var.lifecycle_rule != null ||
    var.multipart_abort_days_after_initiation != null
  ) ? 1 : 0
  bucket = aws_s3_bucket.bucket.id

  dynamic "rule" {
    for_each = var.lifecycle_rule != null ? [var.lifecycle_rule] : []
    content {
      id     = "lifecycle_policy"
      status = rule.value.status
      filter {
        prefix = rule.value.prefix
      }

      dynamic "transition" {
        for_each = rule.value.transitions
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }

      dynamic "expiration" {
        for_each = rule.value.expiration != null ? [rule.value.expiration] : []
        content {
          days = expiration.value
        }
      }
    }
  }

  dynamic "rule" {
    for_each = var.multipart_abort_days_after_initiation != null ? [var.multipart_abort_days_after_initiation] : []
    content {
      id     = "abort-incomplete-multipart-uploads"
      status = "Enabled"
      filter {}

      abort_incomplete_multipart_upload {
        days_after_initiation = rule.value
      }
    }
  }
}

# IAM Policy for Read-Only Access
resource "aws_iam_policy" "read_only_policy" {
  name        = "policy-s3-${var.app_alias}-${var.env}-${var.region_short}-${var.detail}-readonly"
  description = "Read-only access policy for s3-${var.app_alias}-${var.env}-${var.region_short}-${var.detail} bucket"
  tags = {
    Name      = "policy-s3-${var.app_alias}-${var.env}-${var.region_short}-${var.detail}-readonly"
    App_Alias = "${var.app_alias}"
  }
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:ListBucket", "s3:GetObject"],
        Resource = ["${aws_s3_bucket.bucket.arn}", "${aws_s3_bucket.bucket.arn}/*"]
      }
    ]
  })
}

# IAM Policy for Full Access
resource "aws_iam_policy" "full_access_policy" {
  name        = "policy-s3-${var.app_alias}-${var.env}-${var.region_short}-${var.detail}-full"
  description = "Full access policy for s3-${var.app_alias}-${var.env}-${var.region_short}-${var.detail} bucket"
  tags = {
    Name      = "policy-s3-${var.app_alias}-${var.env}-${var.region_short}-${var.detail}-full"
    App_Alias = "${var.app_alias}"
  }
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucketVersions", "s3:GetObjectVersion", "s3:GetObjectVersionAttributes", "s3:DeleteObjectVersion", "s3:RestoreObject"],
        Resource = ["${aws_s3_bucket.bucket.arn}", "${aws_s3_bucket.bucket.arn}/*"]
      }
    ]
  })
}

# Bucket policy for cross-account access
resource "aws_s3_bucket_policy" "cross_account_access" {
  count = (length(var.full_access_roles) + length(var.readonly_roles)) > 0 ? 1 : 0
  bucket = aws_s3_bucket.bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      # Full access roles
      length(var.full_access_roles) > 0 ? [
        {
          Sid    = "AllowFullAccess"
          Effect = "Allow"
          Principal = {
            AWS = var.full_access_roles
          }
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket",
            "s3:ListBucketVersions",
            "s3:GetObjectVersion",
            "s3:GetObjectVersionAttributes",
            "s3:DeleteObjectVersion",
            "s3:RestoreObject"
          ]
          Resource = [
            aws_s3_bucket.bucket.arn,
            "${aws_s3_bucket.bucket.arn}/*"
          ]
        }
      ] : [],
      # Read-only roles
      length(var.readonly_roles) > 0 ? [
        {
          Sid    = "AllowReadOnlyAccess"
          Effect = "Allow"
          Principal = {
            AWS = var.readonly_roles
          }
          Action = [
            "s3:GetObject",
            "s3:ListBucket"
          ]
          Resource = [
            aws_s3_bucket.bucket.arn,
            "${aws_s3_bucket.bucket.arn}/*"
          ]
        }
      ] : []
    )
  })
}
