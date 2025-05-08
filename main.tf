terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# DynamoDB Table
resource "aws_dynamodb_table" "chronoworld-showtimes" {
  name         = "ChronoWorldShowtimes"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "showName"

  attribute {
    name = "showName"
    type = "S"
  }

  tags = {
    Name = "ChronoWorld Showtimes Table"
  }

  lifecycle {
    ignore_changes = [tags]
  }
}

# IAM Role for Lambda
resource "aws_iam_role" "chronoworld-lambda-role" {
  name = "chronoworld-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Attach DynamoDB full access policy to the Lambda role
resource "aws_iam_policy_attachment" "chronoworld-lambda-policy" {
  name       = "chronoworld-lambda-policy"
  roles      = [aws_iam_role.chronoworld-lambda-role.name]
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# Lambda Function
resource "aws_lambda_function" "chronoworld-lambda" {
  filename         = "lambda.zip"
  function_name    = "GetChronoWorldShowtimes"
  role             = aws_iam_role.chronoworld-lambda-role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.9"
  source_code_hash = filebase64sha256("lambda.zip")
  timeout          = 5

  lifecycle {
    ignore_changes = [
      filename,
      source_code_hash
    ]
  }
}

# API Gateway (HTTP API)
resource "aws_apigatewayv2_api" "chronoworld-api" {
  name          = "ChronoWorldShowtimeAPI"
  protocol_type = "HTTP"
}

# Lambda Permission for API Gateway
resource "aws_lambda_permission" "chronoworld-api-permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.chronoworld-lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.chronoworld-api.execution_arn}/*/*"
}

# Integration between API Gateway and Lambda
resource "aws_apigatewayv2_integration" "chronoworld-integration" {
  api_id                 = aws_apigatewayv2_api.chronoworld-api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.chronoworld-lambda.invoke_arn
  integration_method     = "POST"
  payload_format_version = "2.0"
}

# API Gateway Route
resource "aws_apigatewayv2_route" "chronoworld-route" {
  api_id    = aws_apigatewayv2_api.chronoworld-api.id
  route_key = "GET /search"
  target    = "integrations/${aws_apigatewayv2_integration.chronoworld-integration.id}"
}

# Manual Deployment (locked to version)
resource "aws_apigatewayv2_deployment" "chronoworld-deployment" {
  api_id = aws_apigatewayv2_api.chronoworld-api.id

  depends_on = [
    aws_apigatewayv2_route.chronoworld-route
  ]
}

# API Gateway Stage (no auto deploy)
resource "aws_apigatewayv2_stage" "chronoworld-stage" {
  api_id        = aws_apigatewayv2_api.chronoworld-api.id
  name          = "$default"
  deployment_id = aws_apigatewayv2_deployment.chronoworld-deployment.id
  auto_deploy   = false

  lifecycle {
    ignore_changes = [deployment_id]
  }
}
