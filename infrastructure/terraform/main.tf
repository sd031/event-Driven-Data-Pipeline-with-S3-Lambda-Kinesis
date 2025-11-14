terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = var.tags
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Local variables
locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name
  
  # Resource naming
  kinesis_stream_name     = "${var.project_name}-stream-${var.environment}"
  raw_bucket_name         = "${var.project_name}-raw-${var.environment}-${local.account_id}"
  processed_bucket_name   = "${var.project_name}-processed-${var.environment}-${local.account_id}"
  metadata_table_name     = "${var.project_name}-metadata-${var.environment}"
  
  # Lambda function names
  kinesis_processor_name  = "${var.project_name}-kinesis-processor-${var.environment}"
  s3_transformer_name     = "${var.project_name}-s3-transformer-${var.environment}"
}
