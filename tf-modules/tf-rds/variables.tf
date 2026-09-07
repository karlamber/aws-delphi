# Common Variables
# The following variables are used in every module

variable "region" {
  description = "The AWS region where resources will be created."
  type        = string
}

variable "account_id" {
  description = "AWS account ID."
  type        = string
}

variable "env" {
  description = "Environment acronym"
  type = string
}

variable "landscape" {
  description = "Landscape name"
  type = string
}

variable "region_short" {
  description = "Shortened version of the AWS Region for naming resources"
}

# Module Specific Variables
# The following variables are required for specific resource values
variable "app_alias" {
  description = "Alias for application specific resources"
  type        = string
  default     = ""
}

variable "engine" {
  description = "Database engine type"
  type        = string
  default     = "aurora-postgresql"
}

variable "engine_version" {
  description = "Database engine version"
  type        = string
  default     = "15.4"
}

variable "database_name" {
  description = "Name of the default database"
  type        = string
  default     = null
}

variable "master_username" {
  description = "Master username for the database"
  type        = string
}

variable "storage_encrypted" {
  description = "Encrypt storage with KMS key"
  type        = bool
  default     = true
}

variable "create_kms_key" {
  description = "Whether to create a new KMS key for encryption"
  type        = bool
  default     = false
}

variable "kms_key_id" {
  description = "KMS Key ID for encryption"
  type        = string
  default     = null
}

variable "backup_retention_period" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

variable "preferred_backup_window" {
  description = "Preferred backup window"
  type        = string
  default     = "05:00-05:45"
}

variable "preferred_maintenance_window" {
  description = "Preferred maintenance window"
  type        = string
  default     = "sun:06:00-sun:06:45"
}

variable "port" {
  description = "Database port"
  type        = number
  default     = 5432
}

variable "serverless_min_capacity" {
  description = "Minimum capacity for serverless scaling"
  type        = number
  default     = 0.5
}

variable "serverless_max_capacity" {
  description = "Maximum capacity for serverless scaling"
  type        = number
  default     = 16
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = false
}

variable "vpc_security_group_ids" {
  description = "VPC Security Groups that allow inbound / outbound traffic to subnets"
  type = list(string)
}

variable "subnet_ids" {
  description = "VPC Subnet IDs used to create the db subnet group"
  type = list(string)
}

variable "subnet_tier" {
  description = "Security tier of the subnet. Public, Private, or Isolated"
  type = string
  default = "isolated"
}

variable "availability_zone_ids" {
  description = "List of specific Availability Zone IDs to use for the RDS cluster. If not provided, will use the first two AZs in the region."
  type        = list(string)
  default     = null
}

variable "create_parameter_group" {
  description = "Whether to create a new parameter group"
  type        = bool
  default     = false
}

variable "parameter_group_family" {
  description = "The family of the DB parameter group"
  type        = string
  default     = null
}

variable "parameter_group_name" {
  description = "Name of an existing parameter group to use if not creating a new one"
  type        = string
  default     = null
}

variable "parameter_group_parameters" {
  description = "List of parameters to set in the parameter group"
  type = list(object({
    name         = string
    value        = string
    apply_method = string
  }))
  default = []
}

variable "enabled_cloudwatch_logs_exports" {
  description = "List of log types to export to CloudWatch Logs. For Aurora PostgreSQL use e.g. [\"postgresql\"] (and optionally \"upgrade\")."
  type        = list(string)
  default     = []
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights on the cluster instance."
  type        = bool
  default     = false
}

variable "performance_insights_retention_period" {
  description = "Days to retain Performance Insights data. 7 (free tier), 731 (2 years), or a multiple of 31 up to 731. Only applies when performance_insights_enabled is true."
  type        = number
  default     = 7
}

variable "performance_insights_kms_key_id" {
  description = "KMS key ID/ARN used to encrypt Performance Insights data. Null uses the default aws/rds key."
  type        = string
  default     = null
}
