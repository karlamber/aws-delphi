resource "aws_iam_policy" "std_lambda" {
  name        = "policy-lambda-${var.app_alias}-${var.env}-${var.region_short}-std_lambda"
  description = "Custom managed policy for Lambda execution"
  tags = {
    App_Alias = var.app_alias
    Name      = "policy-lambda-${var.app_alias}-${var.env}-${var.region_short}-std_lambda"
  }
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParameterHistory",
          "ssm:DescribeParameters"
        ]
        Resource = "arn:aws:ssm:${var.region}:${var.account_id}:parameter/*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecrets"
        ]
        Resource = "arn:aws:secretsmanager:${var.region}:${var.account_id}:secret:*"
      }
    ]
  })
}


