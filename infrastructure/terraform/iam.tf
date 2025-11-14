# IAM Role for Kinesis Processor Lambda
resource "aws_iam_role" "kinesis_processor_role" {
  name = "${local.kinesis_processor_name}-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name = "${local.kinesis_processor_name}-role"
  }
}

# IAM Policy for Kinesis Processor Lambda
resource "aws_iam_role_policy" "kinesis_processor_policy" {
  name = "${local.kinesis_processor_name}-policy"
  role = aws_iam_role.kinesis_processor_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kinesis:GetRecords",
          "kinesis:GetShardIterator",
          "kinesis:DescribeStream",
          "kinesis:ListStreams",
          "kinesis:ListShards"
        ]
        Resource = aws_kinesis_stream.data_stream.arn
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.raw_data.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.metadata.arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = aws_kms_key.kinesis_key.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:*"
      }
    ]
  })
}

# IAM Role for S3 Transformer Lambda
resource "aws_iam_role" "s3_transformer_role" {
  name = "${local.s3_transformer_name}-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name = "${local.s3_transformer_name}-role"
  }
}

# IAM Policy for S3 Transformer Lambda
resource "aws_iam_role_policy" "s3_transformer_policy" {
  name = "${local.s3_transformer_name}-policy"
  role = aws_iam_role.s3_transformer_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion"
        ]
        Resource = "${aws_s3_bucket.raw_data.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl"
        ]
        Resource = "${aws_s3_bucket.processed_data.arn}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.metadata.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${local.region}:${local.account_id}:*"
      }
    ]
  })
}

# Attach AWS managed policy for Lambda basic execution
resource "aws_iam_role_policy_attachment" "kinesis_processor_basic" {
  role       = aws_iam_role.kinesis_processor_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "s3_transformer_basic" {
  role       = aws_iam_role.s3_transformer_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
