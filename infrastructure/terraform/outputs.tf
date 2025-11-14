output "kinesis_stream_name" {
  description = "Name of the Kinesis Data Stream"
  value       = aws_kinesis_stream.data_stream.name
}

output "kinesis_stream_arn" {
  description = "ARN of the Kinesis Data Stream"
  value       = aws_kinesis_stream.data_stream.arn
}

output "raw_bucket_name" {
  description = "Name of the raw data S3 bucket"
  value       = aws_s3_bucket.raw_data.id
}

output "raw_bucket_arn" {
  description = "ARN of the raw data S3 bucket"
  value       = aws_s3_bucket.raw_data.arn
}

output "processed_bucket_name" {
  description = "Name of the processed data S3 bucket"
  value       = aws_s3_bucket.processed_data.id
}

output "processed_bucket_arn" {
  description = "ARN of the processed data S3 bucket"
  value       = aws_s3_bucket.processed_data.arn
}

output "metadata_table_name" {
  description = "Name of the DynamoDB metadata table"
  value       = aws_dynamodb_table.metadata.name
}

output "metadata_table_arn" {
  description = "ARN of the DynamoDB metadata table"
  value       = aws_dynamodb_table.metadata.arn
}

output "kinesis_processor_function_name" {
  description = "Name of the Kinesis processor Lambda function"
  value       = aws_lambda_function.kinesis_processor.function_name
}

output "kinesis_processor_function_arn" {
  description = "ARN of the Kinesis processor Lambda function"
  value       = aws_lambda_function.kinesis_processor.arn
}

output "s3_transformer_function_name" {
  description = "Name of the S3 transformer Lambda function"
  value       = aws_lambda_function.s3_transformer.function_name
}

output "s3_transformer_function_arn" {
  description = "ARN of the S3 transformer Lambda function"
  value       = aws_lambda_function.s3_transformer.arn
}

output "kinesis_processor_dlq_url" {
  description = "URL of the Kinesis processor DLQ"
  value       = aws_sqs_queue.kinesis_processor_dlq.url
}

output "s3_transformer_dlq_url" {
  description = "URL of the S3 transformer DLQ"
  value       = aws_sqs_queue.s3_transformer_dlq.url
}

output "aws_region" {
  description = "AWS region where resources are deployed"
  value       = var.aws_region
}

output "environment" {
  description = "Environment name"
  value       = var.environment
}

# Summary output for easy reference
output "deployment_summary" {
  description = "Summary of deployed resources"
  value = {
    kinesis_stream    = aws_kinesis_stream.data_stream.name
    raw_bucket        = aws_s3_bucket.raw_data.id
    processed_bucket  = aws_s3_bucket.processed_data.id
    metadata_table    = aws_dynamodb_table.metadata.name
    lambda_processor  = aws_lambda_function.kinesis_processor.function_name
    lambda_transformer = aws_lambda_function.s3_transformer.function_name
    region            = var.aws_region
    environment       = var.environment
  }
}
