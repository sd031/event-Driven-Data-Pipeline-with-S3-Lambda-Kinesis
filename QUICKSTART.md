# Quick Start Guide

Get the Event-Driven Data Pipeline running in 10 minutes!

## Prerequisites Check

```bash
# Check AWS CLI
aws --version
# Should show: aws-cli/2.x.x or higher

# Check Terraform
terraform --version
# Should show: Terraform v1.x.x or higher

# Check Python
python3 --version
# Should show: Python 3.9.x or higher

# Check AWS credentials
aws sts get-caller-identity
# Should show your AWS account details
```

If any command fails, see [Setup Guide](docs/setup-guide.md) for installation instructions.

## Step 1: Configure AWS (2 minutes)

```bash
# If not already configured
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter default region: us-east-1
# Enter default output format: json
```

## Step 2: Deploy Infrastructure (5 minutes)

```bash
# Navigate to scripts directory
cd scripts

# Make scripts executable
chmod +x *.sh

# Run deployment
./deploy.sh
```

The script will:
- ✅ Check prerequisites
- ✅ Install Lambda dependencies
- ✅ Initialize Terraform
- ✅ Deploy all AWS resources
- ✅ Configure data producer

**Note:** You'll be asked to confirm the deployment. Type `yes` when prompted.

## Step 3: Test the Pipeline (2 minutes)

```bash
# Run automated tests
./test-pipeline.sh
```

This will:
- Send 50 test events to Kinesis
- Wait for processing
- Verify data in S3 and DynamoDB
- Show test results

## Step 4: Generate Real Data (1 minute)

```bash
# Navigate to producer directory
cd ../data-producer

# Start sending data (runs for 60 seconds)
python3 producer.py --config config.yaml
```

Watch the output to see records being sent!

## Step 5: Monitor the Pipeline

```bash
# Return to scripts directory
cd ../scripts

# View monitoring dashboard
./monitor.sh
```

This shows:
- Kinesis stream metrics
- Lambda function statistics
- S3 object counts
- DynamoDB item counts
- Recent logs

## Explore Your Data

### View Raw Data in S3

```bash
# Get bucket name from Terraform output
cd ../infrastructure/terraform
RAW_BUCKET=$(terraform output -raw raw_bucket_name)

# List raw data files
aws s3 ls s3://$RAW_BUCKET/raw/ --recursive

# Download a sample file
aws s3 cp s3://$RAW_BUCKET/raw/event_type=user_action/year=2024/month=01/day=15/hour=10/data_*.json sample.json

# View contents
cat sample.json | jq
```

### View Processed Data in S3

```bash
# Get bucket name
PROCESSED_BUCKET=$(terraform output -raw processed_bucket_name)

# List processed data files
aws s3 ls s3://$PROCESSED_BUCKET/processed/ --recursive

# Download a sample file
aws s3 cp s3://$PROCESSED_BUCKET/processed/event_type=user_action/year=2024/month=01/day=15/hour=10/*_transformed_*.json sample-processed.json

# View contents
cat sample-processed.json | jq
```

### Query DynamoDB Metadata

```bash
# Get table name
METADATA_TABLE=$(terraform output -raw metadata_table_name)

# Scan table
aws dynamodb scan --table-name $METADATA_TABLE --limit 5 | jq
```

### View Lambda Logs

```bash
# Get function names
KINESIS_PROCESSOR=$(terraform output -raw kinesis_processor_function_name)
S3_TRANSFORMER=$(terraform output -raw s3_transformer_function_name)

# Tail Kinesis processor logs
aws logs tail /aws/lambda/$KINESIS_PROCESSOR --follow

# In another terminal, tail S3 transformer logs
aws logs tail /aws/lambda/$S3_TRANSFORMER --follow
```

## Common Commands

### Send More Data

```bash
cd data-producer

# Send 100 records at 20 per second for 5 seconds
python3 producer.py --stream YOUR_STREAM_NAME --rate 20 --duration 5

# Send 1000 records for load testing
python3 producer.py --stream YOUR_STREAM_NAME --rate 100 --duration 10
```

### Check Pipeline Health

```bash
cd scripts
./monitor.sh
```

### View CloudWatch Dashboards

```bash
# Open CloudWatch console
open "https://console.aws.amazon.com/cloudwatch/"
```

### Check for Errors

```bash
# Check Kinesis processor errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/$KINESIS_PROCESSOR \
  --filter-pattern "ERROR" \
  --start-time $(date -u -v-1H +%s)000

# Check S3 transformer errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/$S3_TRANSFORMER \
  --filter-pattern "ERROR" \
  --start-time $(date -u -v-1H +%s)000
```

### Check Dead Letter Queues

```bash
# Get DLQ URLs
KINESIS_DLQ=$(cd ../infrastructure/terraform && terraform output -raw kinesis_processor_dlq_url)
S3_DLQ=$(cd ../infrastructure/terraform && terraform output -raw s3_transformer_dlq_url)

# Check for failed messages
aws sqs get-queue-attributes \
  --queue-url $KINESIS_DLQ \
  --attribute-names ApproximateNumberOfMessages

aws sqs get-queue-attributes \
  --queue-url $S3_DLQ \
  --attribute-names ApproximateNumberOfMessages
```

## Cleanup (Important!)

**When you're done testing, destroy all resources to avoid charges:**

```bash
cd scripts
./cleanup.sh
```

Type `yes` when prompted to confirm destruction.

## Troubleshooting

### Issue: Terraform apply fails

```bash
# Clear cache and retry
cd infrastructure/terraform
rm -rf .terraform
rm .terraform.lock.hcl
terraform init
terraform apply
```

### Issue: No data appearing in S3

1. Check if data is being sent:
   ```bash
   aws kinesis describe-stream --stream-name YOUR_STREAM_NAME
   ```

2. Check Lambda logs for errors:
   ```bash
   aws logs tail /aws/lambda/$KINESIS_PROCESSOR --since 5m
   ```

3. Verify IAM permissions

### Issue: High costs

1. Stop the data producer
2. Reduce Kinesis shard count
3. Run cleanup script when not testing

### Need More Help?

- See [Troubleshooting Guide](docs/troubleshooting.md)
- See [Setup Guide](docs/setup-guide.md)
- Check [Architecture Documentation](docs/architecture.md)

## What's Next?

### Learn More

- **Architecture:** Read [docs/architecture.md](docs/architecture.md) to understand the system design
- **Customization:** Modify Lambda functions to add your own logic
- **Scaling:** Increase Kinesis shards and Lambda memory for higher throughput
- **Analytics:** Connect Amazon Athena to query S3 data

### Extend the Pipeline

1. **Add Real-Time Analytics:**
   - Integrate Kinesis Data Analytics
   - Create streaming SQL queries
   - Build real-time dashboards

2. **Add Data Catalog:**
   - Use AWS Glue Crawler
   - Query with Amazon Athena
   - Visualize with QuickSight

3. **Add Notifications:**
   - SNS for alerts
   - Email notifications
   - Slack integration

4. **Add Machine Learning:**
   - Anomaly detection
   - Predictive analytics
   - Real-time scoring

### Production Considerations

Before using in production:

1. **Security:**
   - Enable VPC endpoints
   - Use AWS Secrets Manager
   - Enable CloudTrail
   - Review IAM policies

2. **Monitoring:**
   - Set up CloudWatch dashboards
   - Configure SNS alerts
   - Enable X-Ray tracing
   - Set up log aggregation

3. **Reliability:**
   - Enable cross-region replication
   - Set up automated backups
   - Test disaster recovery
   - Document runbooks

4. **Cost Optimization:**
   - Right-size resources
   - Set up cost alerts
   - Use Reserved Capacity
   - Implement lifecycle policies

## Cost Estimate

Running this pipeline 24/7:

- **Development:** ~$30-60/month
- **Production (medium traffic):** ~$150-300/month

**To minimize costs during testing:**
- Run cleanup script when not in use
- Reduce Kinesis shard count
- Set short log retention
- Use on-demand billing

## Support

- 📖 [Full Documentation](README.md)
- 🔧 [Troubleshooting](docs/troubleshooting.md)
- 🏗️ [Architecture](docs/architecture.md)
- 🤝 [Contributing](CONTRIBUTING.md)

## Success! 🎉

You now have a fully functional event-driven data pipeline running on AWS!

**Remember to run `./cleanup.sh` when done to avoid charges!**
