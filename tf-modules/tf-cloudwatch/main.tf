# Create IAM Role
resource "aws_iam_role" "cloudwatch_logging_role" {
  name = "role-${var.landscape}-${var.env}-${var.region_short}-cloudwatch_logging"
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect    = "Allow",
        Principal = {
          Service = [
            "apigateway.amazonaws.com",
            "lambda.amazonaws.com",
            "sqs.amazonaws.com",
            "sns.amazonaws.com",
            "ecs.amazonaws.com",
            "ecs-tasks.amazonaws.com",
            "delivery.logs.amazonaws.com",
            "logs.amazonaws.com"
          ]
        },
        Action    = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name = "role-${var.landscape}-${var.env}-${var.region_short}-cloudwatch_logging"
  }
}

# Attach Policy for CloudWatch Logging
resource "aws_iam_policy" "cloudwatch_logging_policy" {
  name        =   "policy-${var.landscape}-${var.env}-${var.region_short}-cloudwatch_logging"
  description = "Policy to allow logging to CloudWatch"
  policy      = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect   : "Allow",
        Action   : [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents"
        ],
        Resource : "*"
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "cloudwatch_logging_attachment" {
  role       = aws_iam_role.cloudwatch_logging_role.name
  policy_arn = aws_iam_policy.cloudwatch_logging_policy.arn
}

# Attach the AmazonAPIGatewayPushToCloudWatchLogs policy to the role
resource "aws_iam_role_policy_attachment" "AmazonAPIGatewayPushToCloudWatchLogs" {
 role = aws_iam_role.cloudwatch_logging_role.name
 policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}
