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

variable "vpc_cidr" {
  description = "Regional VPC CIDR (/21). Account blocks are /20; each region uses one /21 half (e.g. 10.0.0.0/21)."
  type        = string

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0)) && tonumber(split("/", var.vpc_cidr)[1]) == 21
    error_message = "vpc_cidr must be a valid IPv4 CIDR with prefix length /21."
  }
}

# Define a boolean variable to control the creation
variable "create_internet_gateway" {
  description = "Should an internet gateway be created?"
  type        = bool
  default     = false
}

# Define a boolean variable to control the creation
variable "create_nat_gateways" {
  description = "Should an NAT gateways be created?"
  type        = bool
  default     = false
}

variable "retention_in_days" {
  description = "Number of days to retain log data"
  type = number
  default = 30
}

variable "availability_zone_ids" {
  description = "AZ IDs for subnets (1–3). If null, uses the first AZ only (minimal: one public /25, one private /24, one isolated /25)."
  type        = list(string)
  default     = null

  validation {
    condition     = var.availability_zone_ids == null || (length(var.availability_zone_ids) >= 1 && length(var.availability_zone_ids) <= 3)
    error_message = "availability_zone_ids must contain 1 to 3 AZs (or be null for a single AZ)."
  }
}

variable "create_ssm_vpc_endpoints" {
  description = "Create VPC interface endpoints for SSM (ssm, ec2messages, ssmmessages). Required for SSM Session Manager / port forwarding when the VPC has no Internet Gateway or NAT Gateways."
  type        = bool
  default     = false
}
