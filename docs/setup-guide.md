# Setup Guide

## Prerequisites

Before you begin, ensure you have the following installed and configured:

### Required Software

1. **AWS CLI** (version 2.x or later)
   ```bash
   # Install on macOS
   brew install awscli
   
   # Verify installation
   aws --version
   ```

2. **Terraform** (version 1.0 or later)
   ```bash
   # Install on macOS
   brew tap hashicorp/tap
   brew install hashicorp/tap/terraform
   
   # Verify installation
   terraform --version
   ```

3. **Python 3.9+**
   ```bash
   # Check version
   python3 --version
   
   # Install pip if needed
   python3 -m ensurepip --upgrade
   ```

4. **jq** (for JSON processing in scripts)
   ```bash
   brew install jq
   ```

### AWS Account Setup

1. **Create an AWS Account** (if you don't have one)
   - Visit https://aws.amazon.com/
   - Sign up for a new account

2. **Create an IAM User** with appropriate permissions
   - Navigate to IAM Console
   - Create a new user with programmatic access
   - Attach the following policies:
     - `AmazonKinesisFullAccess`
     - `AmazonS3FullAccess`
     - `AmazonDynamoDBFullAccess`
     - `AWSLambda_FullAccess`
     - `IAMFullAccess` (for role creation)
     - `CloudWatchFullAccess`

3. **Configure AWS CLI**
   ```bash
   aws configure
   ```
   Enter your:
   - AWS Access Key ID
   - AWS Secret Access Key
   - Default region (e.g., `us-east-1`)
   - Default output format (e.g., `json`)

4. **Verify Configuration**
   ```bash
   aws sts get-caller-identity
   ```

## Installation Steps

### 1. Clone the Project

```bash
cd /Users/sandipdas/final_aws_project_6
```

### 2. Install Python Dependencies

```bash
# Install producer dependencies
cd data-producer
pip3 install -r requirements.txt

# Install Lambda dependencies (optional for local testing)
cd ../lambda/kinesis-processor
pip3 install -r requirements.txt

cd ../s3-transformer
pip3 install -r requirements.txt
```

### 3. Configure Terraform Variables (Optional)

Edit `infrastructure/terraform/terraform.tfvars`:

```hcl
aws_region = "us-east-1"
environment = "dev"
project_name = "event-driven-pipeline"
kinesis_shard_count = 2
lambda_memory_size = 512
lambda_timeout = 60
```

### 4. Make Scripts Executable

```bash
cd ../../scripts
chmod +x *.sh
```

## Deployment

### Quick Deployment

Run the automated deployment script:

```bash
cd scripts
./deploy.sh
```

This script will:
1. Check prerequisites
2. Verify AWS credentials
3. Install Lambda dependencies
4. Initialize Terraform
5. Deploy all infrastructure
6. Update producer configuration
7. Display resource information

### Manual Deployment

If you prefer manual deployment:

```bash
# 1. Initialize Terraform
cd infrastructure/terraform
terraform init

# 2. Review the plan
terraform plan

# 3. Apply the configuration
terraform apply

# 4. Save outputs
terraform output -json > outputs.json
```

## Post-Deployment Verification

### 1. Check Resources

```bash
# List Kinesis streams
aws kinesis list-streams

# List S3 buckets
aws s3 ls | grep event-driven-pipeline

# List DynamoDB tables
aws dynamodb list-tables | grep pipeline-metadata

# List Lambda functions
aws lambda list-functions | grep event-driven-pipeline
```

### 2. Test the Pipeline

```bash
cd scripts
./test-pipeline.sh
```

### 3. Monitor the Pipeline

```bash
./monitor.sh
```

## Configuration

### Producer Configuration

Edit `data-producer/config.yaml`:

```yaml
aws:
  region: us-east-1

kinesis:
  stream_name: event-driven-pipeline-stream-dev

producer:
  rate: 10              # Records per second
  duration: 60          # Duration in seconds
  batch_size: 10        # Records per batch
```

### Lambda Environment Variables

Lambda functions use the following environment variables (automatically set by Terraform):

**Kinesis Processor:**
- `RAW_BUCKET_NAME`: S3 bucket for raw data
- `METADATA_TABLE_NAME`: DynamoDB table name
- `ENABLE_VALIDATION`: Enable data validation (true/false)
- `LOG_LEVEL`: Logging level (INFO, DEBUG, etc.)

**S3 Transformer:**
- `PROCESSED_BUCKET_NAME`: S3 bucket for processed data
- `METADATA_TABLE_NAME`: DynamoDB table name
- `LOG_LEVEL`: Logging level

## Troubleshooting

### Common Issues

1. **Terraform Init Fails**
   ```bash
   # Clear Terraform cache
   rm -rf .terraform
   rm .terraform.lock.hcl
   terraform init
   ```

2. **AWS Credentials Error**
   ```bash
   # Reconfigure AWS CLI
   aws configure
   
   # Test credentials
   aws sts get-caller-identity
   ```

3. **Lambda Deployment Fails**
   ```bash
   # Ensure dependencies are installed
   cd lambda/kinesis-processor
   pip3 install -r requirements.txt -t .
   ```

4. **S3 Bucket Already Exists**
   - Bucket names must be globally unique
   - Edit `infrastructure/terraform/variables.tf` to change project name

### Getting Help

- Check CloudWatch Logs for Lambda errors
- Review Terraform output for deployment issues
- Verify IAM permissions
- Check AWS service quotas

## Next Steps

After successful setup:

1. **Run the Data Producer**
   ```bash
   cd data-producer
   python3 producer.py --config config.yaml
   ```

2. **Monitor the Pipeline**
   ```bash
   cd ../scripts
   ./monitor.sh
   ```

3. **View Data in S3**
   ```bash
   # Raw data
   aws s3 ls s3://YOUR-RAW-BUCKET/raw/ --recursive
   
   # Processed data
   aws s3 ls s3://YOUR-PROCESSED-BUCKET/processed/ --recursive
   ```

4. **Query DynamoDB Metadata**
   ```bash
   aws dynamodb scan --table-name YOUR-METADATA-TABLE
   ```

## Cleanup

When you're done testing:

```bash
cd scripts
./cleanup.sh
```

This will destroy all resources to avoid ongoing charges.

## Cost Estimation

Expected costs for running this pipeline (assuming low traffic):

- **Kinesis Data Stream**: $0.015 per shard-hour (~$22/month for 2 shards)
- **Lambda**: First 1M requests free, then $0.20 per 1M requests
- **S3**: $0.023 per GB stored
- **DynamoDB**: On-demand pricing, ~$1.25 per million write requests
- **CloudWatch**: First 5GB of logs free

**Total estimated cost**: $30-60/month for development/testing

Remember to run cleanup script when not in use!
