# outputs.tf

# Output for AWS KMS Key ARN
output "kms_key_arn" {
  description = "The ARN of the KMS key used for the RDS cluster."
  value       = var.create_kms_key ? aws_kms_key.this[0].arn : var.kms_key_id
}

# Output for AWS KMS Key ID (Optional)
output "kms_key_id" {
  description = "The ID of the KMS key used for the RDS cluster."
  value       = var.create_kms_key ? aws_kms_key.this[0].key_id : var.kms_key_id
}

# Output for DB Subnet Group Name
output "db_subnet_group_name" {
  description = "The name of the DB subnet group used by the RDS cluster."
  value       = aws_db_subnet_group.this.name
}

# Output for RDS Cluster Endpoint
output "cluster_endpoint" {
  description = "The endpoint address of the RDS cluster."
  value       = aws_rds_cluster.this.endpoint
}

# Output for RDS Cluster Reader Endpoint
output "cluster_reader_endpoint" {
  description = "The reader endpoint address of the RDS cluster."
  value       = aws_rds_cluster.this.reader_endpoint
}

# Output for RDS Cluster ID
output "cluster_id" {
  description = "The ID of the RDS cluster."
  value       = aws_rds_cluster.this.id
}

# Output for RDS Cluster ARN
output "cluster_arn" {
  description = "The ARN of the RDS cluster."
  value       = aws_rds_cluster.this.arn
}

# Output for RDS Cluster Instance Endpoint
output "instance_endpoint" {
  description = "The endpoint address of the RDS cluster instance."
  value       = aws_rds_cluster_instance.this.endpoint
}

# Output for RDS Cluster Instance ID
output "instance_id" {
  description = "The ID of the RDS cluster instance."
  value       = aws_rds_cluster_instance.this.id
}

# Output for RDS Cluster Instance ARN
output "instance_arn" {
  description = "The ARN of the RDS cluster instance."
  value       = aws_rds_cluster_instance.this.arn
}

# Output for Availability Zones Used
output "availability_zones" {
  description = "The list of availability zone names used by the RDS cluster."
  value       = local.az_names
}

# Output for Database Name
output "database_name" {
  description = "The name of the database created in the RDS cluster."
  value       = aws_rds_cluster.this.database_name
}

# Output for Master Username
output "master_username" {
  description = "The master username for the RDS cluster."
  value       = aws_rds_cluster.this.master_username
}

# Output for Port
output "cluster_port" {
  description = "The port on which the RDS cluster accepts connections."
  value       = aws_rds_cluster.this.port
}

# Output for Subnet IDs Used
output "subnet_ids" {
  description = "The list of subnet IDs associated with the RDS cluster's subnet group."
  value       = aws_db_subnet_group.this.subnet_ids
}

# Output for Secrets Manager Secret ARN
output "secret_arn" {
  description = "Secrets Manager ARN for the managed secret for the postgres user"
  value = aws_rds_cluster.this.master_user_secret[0]["secret_arn"]
}
