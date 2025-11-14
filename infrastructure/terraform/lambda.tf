# Archive Lambda function code - Kinesis Processor
data "archive_file" "kinesis_processor" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda/kinesis-processor"
  output_path = "${path.module}/../../lambda/kinesis-processor.zip"
  excludes    = ["tests", "__pycache__", "*.pyc"]
}

# Archive Lambda function code - S3 Transformer
data "archive_file" "s3_transformer" {
  type        = "zip"
  source_dir  = "${path.module}/../../lambda/s3-transformer"
  output_path = "${path.module}/../../lambda/s3-transformer.zip"
  excludes    = ["tests", "__pycache__", "*.pyc"]
}

# CloudWatch Log Group for Kinesis Processor
resource "aws_cloudwatch_log_group" "kinesis_processor_logs" {
  name              = "/aws/lambda/${local.kinesis_processor_name}"
  retention_in_days = var.log_retention_days
  
  tags = {
    Name = "${local.kinesis_processor_name}-logs"
  }
}

# CloudWatch Log Group for S3 Transformer
resource "aws_cloudwatch_log_group" "s3_transformer_logs" {
  name              = "/aws/lambda/${local.s3_transformer_name}"
  retention_in_days = var.log_retention_days
  
  tags = {
    Name = "${local.s3_transformer_name}-logs"
  }
}

# Lambda Function - Kinesis Processor
resource "aws_lambda_function" "kinesis_processor" {
  filename         = data.archive_file.kinesis_processor.output_path
  function_name    = local.kinesis_processor_name
  role            = aws_iam_role.kinesis_processor_role.arn
  handler         = "handler.lambda_handler"
  source_code_hash = data.archive_file.kinesis_processor.output_base64sha256
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size
  
  environment {
    variables = {
      RAW_BUCKET_NAME      = aws_s3_bucket.raw_data.id
      METADATA_TABLE_NAME  = aws_dynamodb_table.metadata.name
      ENABLE_VALIDATION    = "true"
      LOG_LEVEL           = "INFO"
    }
  }
  
  dead_letter_config {
    target_arn = aws_sqs_queue.kinesis_processor_dlq.arn
  }
  
  tracing_config {
    mode = "Active"
  }
  
  depends_on = [
    aws_cloudwatch_log_group.kinesis_processor_logs,
    aws_iam_role_policy.kinesis_processor_policy
  ]
  
  tags = {
    Name = local.kinesis_processor_name
  }
}

# Lambda Function - S3 Transformer
resource "aws_lambda_function" "s3_transformer" {
  filename         = data.archive_file.s3_transformer.output_path
  function_name    = local.s3_transformer_name
  role            = aws_iam_role.s3_transformer_role.arn
  handler         = "handler.lambda_handler"
  source_code_hash = data.archive_file.s3_transformer.output_base64sha256
  runtime         = var.lambda_runtime
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size
  
  environment {
    variables = {
      PROCESSED_BUCKET_NAME = aws_s3_bucket.processed_data.id
      METADATA_TABLE_NAME   = aws_dynamodb_table.metadata.name
      LOG_LEVEL            = "INFO"
    }
  }
  
  dead_letter_config {
    target_arn = aws_sqs_queue.s3_transformer_dlq.arn
  }
  
  tracing_config {
    mode = "Active"
  }
  
  depends_on = [
    aws_cloudwatch_log_group.s3_transformer_logs,
    aws_iam_role_policy.s3_transformer_policy
  ]
  
  tags = {
    Name = local.s3_transformer_name
  }
}

# Event Source Mapping - Kinesis to Lambda
resource "aws_lambda_event_source_mapping" "kinesis_to_lambda" {
  event_source_arn  = aws_kinesis_stream.data_stream.arn
  function_name     = aws_lambda_function.kinesis_processor.arn
  starting_position = "LATEST"
  batch_size        = 100
  
  maximum_batching_window_in_seconds = 5
  maximum_retry_attempts             = 3
  parallelization_factor            = 1
  
  bisect_batch_on_function_error = true
  
  destination_config {
    on_failure {
      destination_arn = aws_sqs_queue.kinesis_processor_dlq.arn
    }
  }
  
  depends_on = [
    aws_iam_role_policy.kinesis_processor_policy
  ]
}

# Dead Letter Queue for Kinesis Processor
resource "aws_sqs_queue" "kinesis_processor_dlq" {
  name                      = "${local.kinesis_processor_name}-dlq"
  message_retention_seconds = 1209600  # 14 days
  
  tags = {
    Name = "${local.kinesis_processor_name}-dlq"
  }
}

# Dead Letter Queue for S3 Transformer
resource "aws_sqs_queue" "s3_transformer_dlq" {
  name                      = "${local.s3_transformer_name}-dlq"
  message_retention_seconds = 1209600  # 14 days
  
  tags = {
    Name = "${local.s3_transformer_name}-dlq"
  }
}

# IAM policy for Lambda to send to DLQ
resource "aws_iam_role_policy" "kinesis_processor_dlq_policy" {
  name = "${local.kinesis_processor_name}-dlq-policy"
  role = aws_iam_role.kinesis_processor_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.kinesis_processor_dlq.arn
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3_transformer_dlq_policy" {
  name = "${local.s3_transformer_name}-dlq-policy"
  role = aws_iam_role.s3_transformer_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:SendMessage"
        ]
        Resource = aws_sqs_queue.s3_transformer_dlq.arn
      }
    ]
  })
}

# CloudWatch Alarms for Lambda Functions
resource "aws_cloudwatch_metric_alarm" "kinesis_processor_errors" {
  alarm_name          = "${local.kinesis_processor_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors lambda errors"
  
  dimensions = {
    FunctionName = aws_lambda_function.kinesis_processor.function_name
  }
  
  tags = {
    Name = "${local.kinesis_processor_name}-errors-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "s3_transformer_errors" {
  alarm_name          = "${local.s3_transformer_name}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "This metric monitors lambda errors"
  
  dimensions = {
    FunctionName = aws_lambda_function.s3_transformer.function_name
  }
  
  tags = {
    Name = "${local.s3_transformer_name}-errors-alarm"
  }
}

resource "aws_cloudwatch_metric_alarm" "kinesis_processor_throttles" {
  alarm_name          = "${local.kinesis_processor_name}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors lambda throttles"
  
  dimensions = {
    FunctionName = aws_lambda_function.kinesis_processor.function_name
  }
  
  tags = {
    Name = "${local.kinesis_processor_name}-throttles-alarm"
  }
}
