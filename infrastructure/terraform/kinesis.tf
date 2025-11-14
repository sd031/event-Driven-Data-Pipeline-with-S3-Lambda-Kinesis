# Kinesis Data Stream
resource "aws_kinesis_stream" "data_stream" {
  name             = local.kinesis_stream_name
  shard_count      = var.kinesis_shard_count
  retention_period = var.kinesis_retention_hours
  
  shard_level_metrics = [
    "IncomingBytes",
    "IncomingRecords",
    "OutgoingBytes",
    "OutgoingRecords",
    "WriteProvisionedThroughputExceeded",
    "ReadProvisionedThroughputExceeded",
    "IteratorAgeMilliseconds"
  ]
  
  stream_mode_details {
    stream_mode = "PROVISIONED"
  }
  
  encryption_type = "KMS"
  kms_key_id      = aws_kms_key.kinesis_key.id
  
  tags = {
    Name = local.kinesis_stream_name
  }
}

# KMS key for Kinesis encryption
resource "aws_kms_key" "kinesis_key" {
  description             = "KMS key for Kinesis stream encryption"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  
  tags = {
    Name = "${var.project_name}-kinesis-key-${var.environment}"
  }
}

resource "aws_kms_alias" "kinesis_key_alias" {
  name          = "alias/${var.project_name}-kinesis-${var.environment}"
  target_key_id = aws_kms_key.kinesis_key.key_id
}

# CloudWatch alarm for high iterator age
resource "aws_cloudwatch_metric_alarm" "kinesis_iterator_age" {
  alarm_name          = "${local.kinesis_stream_name}-high-iterator-age"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "GetRecords.IteratorAgeMilliseconds"
  namespace           = "AWS/Kinesis"
  period              = "60"
  statistic           = "Maximum"
  threshold           = "60000"  # 1 minute
  alarm_description   = "This metric monitors kinesis iterator age"
  
  dimensions = {
    StreamName = aws_kinesis_stream.data_stream.name
  }
  
  tags = {
    Name = "${local.kinesis_stream_name}-iterator-age-alarm"
  }
}

# CloudWatch alarm for write throughput exceeded
resource "aws_cloudwatch_metric_alarm" "kinesis_write_throughput" {
  alarm_name          = "${local.kinesis_stream_name}-write-throughput-exceeded"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "WriteProvisionedThroughputExceeded"
  namespace           = "AWS/Kinesis"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors kinesis write throughput"
  
  dimensions = {
    StreamName = aws_kinesis_stream.data_stream.name
  }
  
  tags = {
    Name = "${local.kinesis_stream_name}-write-throughput-alarm"
  }
}
