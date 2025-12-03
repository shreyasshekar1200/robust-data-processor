terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-1"
}

# ==============================================================================
# 1. STORAGE & MESSAGING (Database + Queue)
# ==============================================================================

resource "aws_dynamodb_table" "processed_logs" {
  name         = "ProcessedLogs"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "tenant_id"
  range_key    = "log_id"

  attribute {
    name = "tenant_id"
    type = "S"
  }

  attribute {
    name = "log_id"
    type = "S"
  }
}

resource "aws_sqs_queue" "ingestion_queue" {
  name                       = "log-ingestion-queue"
  message_retention_seconds  = 86400
  visibility_timeout_seconds = 30 # Must be >= Lambda timeout
}

# ==============================================================================
# 2. IAM ROLES (Permissions)
# ==============================================================================

# Unified Role for Lambdas (Can read/write to SQS and DynamoDB)
resource "aws_iam_role" "lambda_role" {
  name = "RobustBackendRole_TF"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Attach standard logging permissions
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom Policy for SQS and DynamoDB Access
resource "aws_iam_role_policy" "lambda_policy" {
  name = "RobustBackendPolicy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.ingestion_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.processed_logs.arn
      }
    ]
  })
}

# ==============================================================================
# 3. COMPUTE (Lambda Functions)
# ==============================================================================

# ZIP the code for the Ingestion API
data "archive_file" "api_zip" {
  type        = "zip"
  source_file = "../dist/api/index.js"
  output_path = "${path.module}/api.zip"
}

# ZIP the code for the Worker
data "archive_file" "worker_zip" {
  type        = "zip"
  source_file = "../dist/worker/index.js"
  output_path = "${path.module}/worker.zip"
}

# Component A: Ingestion API Lambda
resource "aws_lambda_function" "ingestion_api" {
  filename         = data.archive_file.api_zip.output_path
  function_name    = "IngestionAPI"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.api_zip.output_base64sha256
  runtime          = "nodejs18.x"

  environment {
    variables = {
      QUEUE_URL = aws_sqs_queue.ingestion_queue.id
    }
  }
}

# Component B: Worker Lambda
resource "aws_lambda_function" "worker" {
  filename         = data.archive_file.worker_zip.output_path
  function_name    = "LogWorker"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.worker_zip.output_base64sha256
  runtime          = "nodejs18.x"
  timeout          = 20 # Worker needs more time for "heavy sleep"

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.processed_logs.name
    }
  }
}

# Trigger: Connect SQS to Worker Lambda
resource "aws_lambda_event_source_mapping" "sqs_trigger" {
  event_source_arn = aws_sqs_queue.ingestion_queue.arn
  function_name    = aws_lambda_function.worker.arn
  batch_size       = 10
}

# ==============================================================================
# 4. API GATEWAY (Public Endpoint)
# ==============================================================================

resource "aws_apigatewayv2_api" "gateway" {
  name          = "IngestionGateway"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.gateway.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.gateway.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.ingestion_api.invoke_arn
  payload_format_version = "2.0"
}

# Route: POST /ingest
resource "aws_apigatewayv2_route" "ingest_route" {
  api_id    = aws_apigatewayv2_api.gateway.id
  route_key = "POST /ingest"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

# Permission: Allow API Gateway to invoke the Lambda
resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.ingestion_api.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.gateway.execution_arn}/*/*"
}

# ==============================================================================
# 5. OUTPUTS
# ==============================================================================

output "api_endpoint" {
  description = "The public URL to test your API"
  value       = "${aws_apigatewayv2_api.gateway.api_endpoint}/ingest"
}
