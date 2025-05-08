provider "aws" {
  region = "us-east-1"
}

# DynamoDB Table
resource "aws_dynamodb_table" "chronoworld_showtimes" {
  name         = "ChronoWorldShowtimes"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "eventName"

  attribute {
    name = "eventName"
    type = "S"
  }

  tags = {
    Name = "ChronoWorld Event Table"
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "chronoworld_lambda_role" {
  name = "chronoworld-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# IAM Policy for Lambda to access DynamoDB
resource "aws_iam_policy" "chronoworld_lambda_dynamodb_policy" {
  name = "chronoworld-lambda-dynamodb-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:Scan"
        ],
        Resource = aws_dynamodb_table.chronoworld_showtimes.arn
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

# Attach IAM Policy to IAM Role
resource "aws_iam_role_policy_attachment" "attach_dynamodb_policy" {
  role       = aws_iam_role.chronoworld_lambda_role.name
  policy_arn = aws_iam_policy.chronoworld_lambda_dynamodb_policy.arn
}

# Lambda Function
resource "aws_lambda_function" "chronoworld_lambda" {
  function_name    = "GetChronoWorldShowtimes"
  role             = aws_iam_role.chronoworld_lambda_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  filename         = "lambda.zip"
  source_code_hash = filebase64sha256("lambda.zip")
  timeout          = 5

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.chronoworld_showtimes.name
    }
  }
}
