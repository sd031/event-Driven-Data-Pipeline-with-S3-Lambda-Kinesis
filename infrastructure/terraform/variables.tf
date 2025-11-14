variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "event-driven-pipeline"
}

variable "kinesis_shard_count" {
  description = "Number of shards for Kinesis stream"
  type        = number
  default     = 2
}

variable "kinesis_retention_hours" {
  description = "Kinesis data retention in hours"
  type        = number
  default     = 24
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda functions (MB)"
  type        = number
  default     = 512
}

variable "lambda_timeout" {
  description = "Timeout for Lambda functions (seconds)"
  type        = number
  default     = 60
}

variable "lambda_runtime" {
  description = "Lambda runtime version"
  type        = string
  default     = "python3.9"
}

variable "enable_cloudwatch_logs" {
  description = "Enable CloudWatch logs for Lambda"
  type        = bool
  default     = true
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "dynamodb_billing_mode" {
  description = "DynamoDB billing mode (PROVISIONED or PAY_PER_REQUEST)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "enable_s3_versioning" {
  description = "Enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "s3_lifecycle_days" {
  description = "Days before transitioning to Glacier"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "EventDrivenPipeline"
    ManagedBy   = "Terraform"
    Environment = "dev"
  }
}
