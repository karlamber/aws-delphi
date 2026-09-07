locals {
  base_name         = join("-", [var.landscape, var.env, var.region_short])
}

# Regional AZs only (exclude Local Zones / Wavelength, which cannot host normal subnets)
data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

# Create the main VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name        = "vpc-${local.base_name}"
    Landscape = var.landscape
  }
}

# Define Availability Zones and fixed CIDR map within the regional /21
# Relative layout (example base 10.0.0.0/21):
#   public  /25: .0.0/25, .0.128/25, .1.0/25
#   private /24: .2.0/24, .3.0/24, .4.0/24
#   isolated /25: .5.0/25, .5.128/25, .6.0/25
#   reserved: .6.128/25 through end of /21 (not created)
locals {
  az_ids = var.availability_zone_ids != null ? var.availability_zone_ids : [data.aws_availability_zones.available.zone_ids[0]]

  public_subnet_cidrs = [
    for i in range(length(local.az_ids)) : cidrsubnet(var.vpc_cidr, 4, i)
  ]
  private_subnet_cidrs = [
    for i in range(length(local.az_ids)) : cidrsubnet(var.vpc_cidr, 3, i + 2)
  ]
  isolated_subnet_cidrs = [
    for i in range(length(local.az_ids)) : cidrsubnet(var.vpc_cidr, 4, i + 10)
  ]
}

# Public Subnets (/25 per AZ)
resource "aws_subnet" "public" {
  count                   = length(local.az_ids)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone_id    = local.az_ids[count.index]

  tags = {
    Name = "subnet-${var.landscape}-${var.env}-${local.az_ids[count.index]}-public"
    Tier = "Public"
  }
}

# Private Subnets (/24 per AZ)
resource "aws_subnet" "private" {
  count                = length(local.az_ids)
  vpc_id               = aws_vpc.main.id
  cidr_block           = local.private_subnet_cidrs[count.index]
  availability_zone_id = local.az_ids[count.index]

  tags = {
    Name = "subnet-${var.landscape}-${var.env}-${local.az_ids[count.index]}-private"
    Tier = "Private"
  }
}

# Isolated Subnets (/25 per AZ)
resource "aws_subnet" "isolated" {
  count                = length(local.az_ids)
  vpc_id               = aws_vpc.main.id
  cidr_block           = local.isolated_subnet_cidrs[count.index]
  availability_zone_id = local.az_ids[count.index]

  tags = {
    Name = "subnet-${var.landscape}-${var.env}-${local.az_ids[count.index]}-isolated"
    Tier = "Isolated"
  }
}

# Security Group for Public Subnets (without cross-references)
resource "aws_security_group" "public" {
  vpc_id = aws_vpc.main.id
  name   = "secgrp-${local.base_name}-public"
  description = "Security Group for public tier subnets"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name   = "secgrp-${local.base_name}-public"
    Tier = "Public"
  }
}

# Security Group for Private Subnets (without cross-references)
resource "aws_security_group" "private" {
  vpc_id = aws_vpc.main.id
  name   = "secgrp-${local.base_name}-private"
  description = "Security Group for private tier subnets"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name   = "secgrp-${local.base_name}-private"
    Tier = "Private"
  }
}

# Security Group for Isolated Subnets (without cross-references)
resource "aws_security_group" "isolated" {
  vpc_id = aws_vpc.main.id
  name   = "secgrp-${local.base_name}-isolated"
  description = "Security Group for isolated tier subnets"

  tags = {
    Name   = "secgrp-${local.base_name}-isolated"
    Tier = "Isolated"
  }
}

# Ingress rules for Private Security Group
resource "aws_security_group_rule" "private_from_public" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.private.id
  source_security_group_id = aws_security_group.public.id
}

resource "aws_security_group_rule" "private_from_isolated" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.private.id
  source_security_group_id = aws_security_group.isolated.id
}

resource "aws_security_group_rule" "private_from_private" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.private.id
  source_security_group_id = aws_security_group.private.id
}

# Ingress rules for Isolated Security Group
resource "aws_security_group_rule" "isolated_from_private" {
  type              = "ingress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.isolated.id
  source_security_group_id = aws_security_group.private.id
}

# Egress rules for Isolated Security Group
resource "aws_security_group_rule" "isolated_to_private" {
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.isolated.id
  source_security_group_id = aws_security_group.private.id
}

# Create S3 VPC Endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.region}.s3"
  route_table_ids = concat(
    [aws_route_table.isolated_rtb.id],
    [aws_route_table.public_rtb.id],
    aws_route_table.private_rtb[*].id
  )
  tags = {
    Name = "vpce-${var.landscape}-${var.env}-${var.region_short}-s3"
  }
}

# Create DynamoDB VPC Endpoint
resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.region}.dynamodb"
  route_table_ids = concat(
    [aws_route_table.isolated_rtb.id],
    [aws_route_table.public_rtb.id],
    aws_route_table.private_rtb[*].id
  )
  tags = {
    Name = "vpce-${var.landscape}-${var.env}-${var.region_short}-dynamodb"
  }
}

# Create Secrets Manager VPC Endpoint
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${var.region}.secretsmanager"
  vpc_endpoint_type = "Interface"
  subnet_ids = aws_subnet.private[*].id
  security_group_ids = [aws_security_group.private.id]
  private_dns_enabled = true
  tags = {
    Name = "vpce-${var.landscape}-${var.env}-${var.region_short}-secretsmanager"
  }
}

# SSM Interface Endpoints (required for SSM Session Manager / port forwarding when no IGW/NAT)
resource "aws_vpc_endpoint" "ssm" {
  count               = var.create_ssm_vpc_endpoints ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.private.id]
  private_dns_enabled = true
  tags = {
    Name = "vpce-${var.landscape}-${var.env}-${var.region_short}-ssm"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  count               = var.create_ssm_vpc_endpoints ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.private.id]
  private_dns_enabled = true
  tags = {
    Name = "vpce-${var.landscape}-${var.env}-${var.region_short}-ec2messages"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  count               = var.create_ssm_vpc_endpoints ? 1 : 0
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.private.id]
  private_dns_enabled = true
  tags = {
    Name = "vpce-${var.landscape}-${var.env}-${var.region_short}-ssmmessages"
  }
}

# Create route tables for all tiers
# Create a public route table
resource "aws_route_table" "public_rtb" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "rtb-${var.landscape}-${var.env}-${var.region_short}-public"
  }
}

# Associate the public subnets with the public route table
resource "aws_route_table_association" "public_subnet_association" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public_rtb.id
}

# Route Tables for Private Subnets
resource "aws_route_table" "private_rtb" {
  count = length(aws_subnet.private)
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "rtb-${var.landscape}-${var.env}-${var.region_short}-private-${count.index + 1}"
  }
}

# Associate the private subnets with their route tables
resource "aws_route_table_association" "private_rtb_association" {
  count = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private_rtb[count.index].id
}

# Create a route table for isolated subnets
resource "aws_route_table" "isolated_rtb" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "rtb-${var.landscape}-${var.env}-${var.region_short}-isolated"
  }
}

# Associate the isolated subnets with their route tables
resource "aws_route_table_association" "isolated_route_table_association" {
  count = length(aws_subnet.isolated)
  subnet_id      = aws_subnet.isolated[count.index].id
  route_table_id = aws_route_table.isolated_rtb.id
}

# Create an Internet Gateway
resource "aws_internet_gateway" "int_gw" {
  count = var.create_internet_gateway ? 1 : 0
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "igw-${var.landscape}-${var.env}-${var.region_short}"
  }
}

# Add a route in the public route table that points 0.0.0.0/0 traffic to the Internet Gateway
resource "aws_route" "internet_access" {
  count = var.create_internet_gateway ? 1 : 0
  route_table_id         = aws_route_table.public_rtb.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.int_gw[0].id
}

# Create an Elastic IP for each NAT Gateway
resource "aws_eip" "nat_eip" {
  count = var.create_nat_gateways ? length(aws_subnet.private) : 0
  tags = {
    Name = "eip-${var.landscape}-${var.env}-${var.region_short}-nat-${count.index + 1}"
  }
}

# NAT Gateways (one per public subnet)
resource "aws_nat_gateway" "nat_gateway" {
  count = var.create_nat_gateways ? length(aws_subnet.public) : 0
  allocation_id = aws_eip.nat_eip[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "nat-${var.landscape}-${var.env}-${var.region_short}-${count.index + 1}"
  }
}

# Route for internet traffic through the NAT Gateway
resource "aws_route" "private_route" {
  count = var.create_nat_gateways ? length(aws_subnet.private) : 0
  route_table_id         = aws_route_table.private_rtb[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway[count.index].id
}

# Create VPC Flow Logs for troubleshooting
resource "aws_flow_log" "vpc_flow_logs" {
  log_destination = aws_cloudwatch_log_group.flow_log_group.arn
  vpc_id               = aws_vpc.main.id
  traffic_type         = "ALL"  # You can also specify "ACCEPT" or "REJECT"
  iam_role_arn         = aws_iam_role.flow_log_role.arn
}

resource "aws_cloudwatch_log_group" "flow_log_group" {
  name = "/aws/vpc/${var.landscape}-${var.env}-${var.region_short}/flow-logs"
  retention_in_days = var.retention_in_days
  tags = {
    Name = "flow-log-${var.landscape}-${var.env}-${var.region_short}-vpc"
  }
}

resource "aws_iam_role" "flow_log_role" {
  name = "role-${var.landscape}-${var.env}-${var.region_short}-flow-logs"
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : "sts:AssumeRole",
        "Principal" : {
          "Service" : "vpc-flow-logs.amazonaws.com"
        },
        "Effect" : "Allow"
      }
    ]
  })
  tags = {
    Name = "role-${var.landscape}-${var.env}-${var.region_short}-flow-logs"
  }
}

resource "aws_iam_role_policy" "flow_log_policy" {
  name = "policy-logs-${var.landscape}-${var.env}-${var.region_short}-flow-logs"
  role = aws_iam_role.flow_log_role.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Effect" : "Allow",
        "Action" : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_s3_bucket" "cloudtrail_bucket" {
  bucket = "s3-${var.landscape}-${var.env}-${var.region_short}-cloudtrail"
  force_destroy = true
    tags = {
      Name = "s3-${var.landscape}-${var.env}-${var.region_short}-cloudtrail"
  }
}

resource "aws_s3_bucket_policy" "cloudtrail_bucket_policy" {
  bucket = aws_s3_bucket.cloudtrail_bucket.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "s3:GetBucketAcl",
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Resource = "${aws_s3_bucket.cloudtrail_bucket.arn}"
      },
      {
        Action = "s3:PutObject",
        Effect = "Allow",
        Principal = {
          Service = "cloudtrail.amazonaws.com"
        },
        Resource = "${aws_s3_bucket.cloudtrail_bucket.arn}/*",
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })
}

resource "aws_cloudtrail" "main" {
  name                          = "cloudtrail-${var.landscape}-${var.env}-${var.region_short}"
  s3_bucket_name                = aws_s3_bucket.cloudtrail_bucket.bucket
  include_global_service_events = true
  is_multi_region_trail         = true
  enable_logging                = true
  tags = {
    Name = "cloudtrail-${var.landscape}-${var.env}-${var.region_short}"
  }
  depends_on = [aws_s3_bucket_policy.cloudtrail_bucket_policy]
}
