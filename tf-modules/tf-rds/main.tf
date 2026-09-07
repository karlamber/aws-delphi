# Data source for AWS availability zones
data "aws_availability_zones" "available" {
  state = "available"
  all_availability_zones = true
}

# KMS policy: allow CloudWatch Logs to use the key for RDS log groups (required when exporting logs from an encrypted cluster)
data "aws_iam_policy_document" "kms_cloudwatch_logs" {
  count = var.create_kms_key ? 1 : 0

  statement {
    sid    = "EnableAccountRoot"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_id}:root"]
    }
    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowCloudWatchLogsRDS"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["logs.${var.region}.amazonaws.com"]
    }
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:CreateGrant",
      "kms:DescribeKey",
    ]
    resources = ["*"]
    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values = [
        "arn:aws:logs:${var.region}:${var.account_id}:log-group:/aws/rds/cluster/rds-${var.app_alias}-${var.env}-${var.region_short}-cluster*",
      ]
    }
  }
}

# Define Availability Zones
locals {
  # If AZ IDs are provided, map them to AZ names, otherwise use first two AZs
  az_names = var.availability_zone_ids != null ? [
    for az_id in var.availability_zone_ids :
    data.aws_availability_zones.available.names[index(data.aws_availability_zones.available.zone_ids, az_id)]
  ] : [data.aws_availability_zones.available.names[0], data.aws_availability_zones.available.names[1]]
}

resource "aws_kms_key" "this" {
  count                   = var.create_kms_key ? 1 : 0
  description             = "KMS key for this RDS cluster"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms_cloudwatch_logs[0].json
  tags = {
    App_Alias = "${var.app_alias}"
    Name      = "kms-${var.app_alias}-${var.env}-${var.region_short}-key"
  }
}

resource "aws_db_subnet_group" "this" {
  name       = "subnet_group-${var.app_alias}-${var.env}-${var.region_short}-${var.subnet_tier}"
  subnet_ids = var.subnet_ids

  tags = {
    App_Alias = "${var.app_alias}"
    Name = "subnet_group-${var.app_alias}-${var.env}-${var.region_short}-${var.subnet_tier}"
  }
}

# Parameter Group Definition
resource "aws_rds_cluster_parameter_group" "this" {
  count  = var.create_parameter_group ? 1 : 0
  family = var.parameter_group_family
  name   = "pg-${var.app_alias}-${var.env}-${var.region_short}-params"

  dynamic "parameter" {
    for_each = var.parameter_group_parameters
    content {
      name         = parameter.value.name
      value        = parameter.value.value
      apply_method = parameter.value.apply_method
    }
  }

  tags = {
    App_Alias = "${var.app_alias}"
    Name      = "pg-${var.app_alias}-${var.env}-${var.region_short}-params"
  }
}

resource "aws_rds_cluster" "this" {
  cluster_identifier          = "rds-${var.app_alias}-${var.env}-${var.region_short}-cluster"
  engine                      = var.engine
  engine_version              = var.engine_version
  database_name               = var.database_name
  master_username             = var.master_username
  manage_master_user_password = true
  storage_encrypted           = var.storage_encrypted
  kms_key_id                  = var.create_kms_key ? aws_kms_key.this[0].arn : var.kms_key_id
  backup_retention_period     = var.backup_retention_period
  preferred_backup_window     = var.preferred_backup_window
  preferred_maintenance_window = var.preferred_maintenance_window
  db_subnet_group_name        = aws_db_subnet_group.this.name
  vpc_security_group_ids      = var.vpc_security_group_ids
  port                        = var.port
  copy_tags_to_snapshot       = true
  deletion_protection         = var.deletion_protection
  skip_final_snapshot         = true
  availability_zones          = local.az_names
  enable_http_endpoint        = true
  db_cluster_parameter_group_name = var.create_parameter_group ? aws_rds_cluster_parameter_group.this[0].name : var.parameter_group_name

  serverlessv2_scaling_configuration {
    min_capacity = var.serverless_min_capacity
    max_capacity = var.serverless_max_capacity
  }

  enabled_cloudwatch_logs_exports = var.enabled_cloudwatch_logs_exports

  lifecycle {
    ignore_changes = [ availability_zones ]
  }

  tags = {
    App_Alias = "${var.app_alias}"
    Name      = "rds-${var.app_alias}-${var.env}-${var.region_short}-cluster"
  }
}

# RDS Cluster Instance Definition
resource "aws_rds_cluster_instance" "this" {
  identifier              = "rds-${var.app_alias}-${var.env}-${var.region_short}-instance"
  cluster_identifier      = aws_rds_cluster.this.id
  engine                  = aws_rds_cluster.this.engine
  engine_version          = aws_rds_cluster.this.engine_version
  instance_class          = "db.serverless"
  publicly_accessible     = false
  db_subnet_group_name    = aws_db_subnet_group.this.name

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
  performance_insights_kms_key_id       = var.performance_insights_enabled ? var.performance_insights_kms_key_id : null

  tags = {
    App_Alias = "${var.app_alias}"
    Name      = "rds-${var.app_alias}-${var.env}-${var.region_short}-instance"
  }
}
