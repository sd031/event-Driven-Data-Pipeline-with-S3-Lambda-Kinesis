# S3 Bucket for Raw Data
resource "aws_s3_bucket" "raw_data" {
  bucket = local.raw_bucket_name
  
  tags = {
    Name        = local.raw_bucket_name
    DataStage   = "raw"
  }
}

# S3 Bucket for Processed Data
resource "aws_s3_bucket" "processed_data" {
  bucket = local.processed_bucket_name
  
  tags = {
    Name        = local.processed_bucket_name
    DataStage   = "processed"
  }
}

# Enable versioning for raw bucket
resource "aws_s3_bucket_versioning" "raw_versioning" {
  bucket = aws_s3_bucket.raw_data.id
  
  versioning_configuration {
    status = var.enable_s3_versioning ? "Enabled" : "Disabled"
  }
}

# Enable versioning for processed bucket
resource "aws_s3_bucket_versioning" "processed_versioning" {
  bucket = aws_s3_bucket.processed_data.id
  
  versioning_configuration {
    status = var.enable_s3_versioning ? "Enabled" : "Disabled"
  }
}

# Server-side encryption for raw bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "raw_encryption" {
  bucket = aws_s3_bucket.raw_data.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Server-side encryption for processed bucket
resource "aws_s3_bucket_server_side_encryption_configuration" "processed_encryption" {
  bucket = aws_s3_bucket.processed_data.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access for raw bucket
resource "aws_s3_bucket_public_access_block" "raw_public_access_block" {
  bucket = aws_s3_bucket.raw_data.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Block public access for processed bucket
resource "aws_s3_bucket_public_access_block" "processed_public_access_block" {
  bucket = aws_s3_bucket.processed_data.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy for raw bucket
resource "aws_s3_bucket_lifecycle_configuration" "raw_lifecycle" {
  bucket = aws_s3_bucket.raw_data.id
  
  rule {
    id     = "transition-to-glacier"
    status = "Enabled"
    
    filter {
      prefix = ""
    }
    
    transition {
      days          = var.s3_lifecycle_days
      storage_class = "GLACIER"
    }
    
    expiration {
      days = var.s3_lifecycle_days + 365
    }
  }
  
  rule {
    id     = "delete-old-versions"
    status = "Enabled"
    
    filter {
      prefix = ""
    }
    
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Lifecycle policy for processed bucket
resource "aws_s3_bucket_lifecycle_configuration" "processed_lifecycle" {
  bucket = aws_s3_bucket.processed_data.id
  
  rule {
    id     = "transition-to-glacier"
    status = "Enabled"
    
    filter {
      prefix = ""
    }
    
    transition {
      days          = var.s3_lifecycle_days
      storage_class = "GLACIER"
    }
    
    expiration {
      days = var.s3_lifecycle_days + 365
    }
  }
}

# S3 Event Notification for Lambda trigger
resource "aws_s3_bucket_notification" "raw_bucket_notification" {
  bucket = aws_s3_bucket.raw_data.id
  
  lambda_function {
    lambda_function_arn = aws_lambda_function.s3_transformer.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "raw/"
    filter_suffix       = ".json"
  }
  
  depends_on = [aws_lambda_permission.allow_s3_invoke]
}

# Lambda permission for S3 to invoke transformer
resource "aws_lambda_permission" "allow_s3_invoke" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_transformer.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.raw_data.arn
}
