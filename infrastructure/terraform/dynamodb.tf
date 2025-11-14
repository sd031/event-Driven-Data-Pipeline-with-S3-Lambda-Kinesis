# DynamoDB table for metadata tracking
resource "aws_dynamodb_table" "metadata" {
  name           = local.metadata_table_name
  billing_mode   = var.dynamodb_billing_mode
  hash_key       = "batch_id"
  range_key      = "processed_at"
  
  attribute {
    name = "batch_id"
    type = "S"
  }
  
  attribute {
    name = "processed_at"
    type = "S"
  }
  
  attribute {
    name = "shard_id"
    type = "S"
  }
  
  # Global Secondary Index for querying by shard
  global_secondary_index {
    name            = "ShardIndex"
    hash_key        = "shard_id"
    range_key       = "processed_at"
    projection_type = "ALL"
  }
  
  # TTL configuration
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }
  
  # Point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }
  
  # Server-side encryption
  server_side_encryption {
    enabled = true
  }
  
  tags = {
    Name = local.metadata_table_name
  }
}

# CloudWatch alarm for DynamoDB throttling
resource "aws_cloudwatch_metric_alarm" "dynamodb_throttle" {
  alarm_name          = "${local.metadata_table_name}-throttle"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UserErrors"
  namespace           = "AWS/DynamoDB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors DynamoDB throttling"
  
  dimensions = {
    TableName = aws_dynamodb_table.metadata.name
  }
  
  tags = {
    Name = "${local.metadata_table_name}-throttle-alarm"
  }
}
