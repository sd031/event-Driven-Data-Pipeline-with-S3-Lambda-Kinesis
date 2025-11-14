# Troubleshooting Guide

## Common Issues and Solutions

### Infrastructure Deployment Issues

#### Issue: Terraform Init Fails

**Symptoms:**
```
Error: Failed to install provider
```

**Solutions:**
```bash
# Clear Terraform cache
cd infrastructure/terraform
rm -rf .terraform
rm .terraform.lock.hcl

# Re-initialize
terraform init
```

#### Issue: S3 Bucket Name Already Exists

**Symptoms:**
```
Error: Error creating S3 bucket: BucketAlreadyExists
```

**Solutions:**
- S3 bucket names must be globally unique
- Edit `infrastructure/terraform/variables.tf`:
  ```hcl
  variable "project_name" {
    default = "event-driven-pipeline-yourname"  # Add unique suffix
  }
  ```

#### Issue: IAM Permission Denied

**Symptoms:**
```
Error: AccessDenied: User is not authorized to perform: iam:CreateRole
```

**Solutions:**
1. Verify your IAM user has required permissions
2. Attach necessary policies:
   ```bash
   aws iam attach-user-policy \
     --user-name YOUR_USERNAME \
     --policy-arn arn:aws:iam::aws:policy/IAMFullAccess
   ```

### Lambda Function Issues

#### Issue: Lambda Timeout

**Symptoms:**
- CloudWatch logs show: `Task timed out after 60.00 seconds`
- High iterator age in Kinesis

**Solutions:**
1. Increase timeout in `infrastructure/terraform/variables.tf`:
   ```hcl
   variable "lambda_timeout" {
     default = 120  # Increase from 60
   }
   ```

2. Apply changes:
   ```bash
   cd infrastructure/terraform
   terraform apply
   ```

#### Issue: Lambda Out of Memory

**Symptoms:**
```
Runtime.OutOfMemory: Lambda function ran out of memory
```

**Solutions:**
1. Increase memory in `infrastructure/terraform/variables.tf`:
   ```hcl
   variable "lambda_memory_size" {
     default = 1024  # Increase from 512
   }
   ```

2. Apply changes:
   ```bash
   terraform apply
   ```

#### Issue: Lambda Import Errors

**Symptoms:**
```
Unable to import module 'handler': No module named 'boto3'
```

**Solutions:**
```bash
# Install dependencies in Lambda directory
cd lambda/kinesis-processor
pip3 install -r requirements.txt -t .

# Redeploy
cd ../../infrastructure/terraform
terraform apply
```

### Kinesis Stream Issues

#### Issue: High Iterator Age

**Symptoms:**
- CloudWatch alarm: `kinesis-high-iterator-age`
- Data processing lag

**Solutions:**
1. **Increase shard count:**
   ```hcl
   variable "kinesis_shard_count" {
     default = 4  # Increase from 2
   }
   ```

2. **Increase Lambda concurrency:**
   ```bash
   aws lambda put-function-concurrency \
     --function-name YOUR_FUNCTION_NAME \
     --reserved-concurrent-executions 10
   ```

3. **Optimize batch size:**
   - Edit `infrastructure/terraform/lambda.tf`
   - Adjust `batch_size` in event source mapping

#### Issue: WriteProvisionedThroughputExceeded

**Symptoms:**
```
ProvisionedThroughputExceededException
```

**Solutions:**
1. Increase shard count
2. Implement exponential backoff in producer
3. Use batch operations instead of single puts

### S3 Issues

#### Issue: S3 Event Notification Not Triggering

**Symptoms:**
- Raw data appears in S3
- No processed data generated
- S3 transformer Lambda not invoked

**Solutions:**
1. **Check S3 notification configuration:**
   ```bash
   aws s3api get-bucket-notification-configuration \
     --bucket YOUR_RAW_BUCKET
   ```

2. **Verify Lambda permission:**
   ```bash
   aws lambda get-policy \
     --function-name YOUR_S3_TRANSFORMER
   ```

3. **Check file prefix/suffix:**
   - Ensure files are in `raw/` prefix
   - Ensure files have `.json` extension

4. **Manually trigger for testing:**
   ```bash
   aws lambda invoke \
     --function-name YOUR_S3_TRANSFORMER \
     --payload file://test-event.json \
     response.json
   ```

#### Issue: Access Denied on S3 Operations

**Symptoms:**
```
An error occurred (AccessDenied) when calling the PutObject operation
```

**Solutions:**
1. Check IAM role permissions
2. Verify bucket policy
3. Check bucket encryption settings

### DynamoDB Issues

#### Issue: Throttling Errors

**Symptoms:**
```
ProvisionedThroughputExceededException
```

**Solutions:**
1. Switch to on-demand billing:
   ```hcl
   variable "dynamodb_billing_mode" {
     default = "PAY_PER_REQUEST"
   }
   ```

2. Or increase provisioned capacity

#### Issue: Item Not Found

**Symptoms:**
- Metadata not appearing in DynamoDB

**Solutions:**
1. Check Lambda CloudWatch logs for errors
2. Verify table name environment variable
3. Check IAM permissions for DynamoDB

### Data Producer Issues

#### Issue: Producer Cannot Connect to Kinesis

**Symptoms:**
```
botocore.exceptions.NoCredentialsError: Unable to locate credentials
```

**Solutions:**
```bash
# Configure AWS credentials
aws configure

# Verify credentials
aws sts get-caller-identity
```

#### Issue: Producer Sending Too Fast

**Symptoms:**
- High costs
- Throttling errors

**Solutions:**
```bash
# Reduce rate
python3 producer.py --rate 5 --duration 30
```

### Monitoring Issues

#### Issue: No Metrics in CloudWatch

**Symptoms:**
- Empty CloudWatch dashboards
- No data in metrics

**Solutions:**
1. Wait 5-10 minutes for metrics to appear
2. Verify resources are being used
3. Check CloudWatch permissions

#### Issue: Logs Not Appearing

**Symptoms:**
- Empty log groups

**Solutions:**
1. Check Lambda execution role has CloudWatch permissions
2. Verify log group exists:
   ```bash
   aws logs describe-log-groups \
     --log-group-name-prefix /aws/lambda/
   ```

3. Create log group manually if needed:
   ```bash
   aws logs create-log-group \
     --log-group-name /aws/lambda/YOUR_FUNCTION
   ```

## Debugging Steps

### 1. Check Lambda Logs

```bash
# Tail logs in real-time
aws logs tail /aws/lambda/YOUR_FUNCTION_NAME --follow

# Get recent errors
aws logs filter-log-events \
  --log-group-name /aws/lambda/YOUR_FUNCTION_NAME \
  --filter-pattern "ERROR" \
  --start-time $(date -u -v-1H +%s)000
```

### 2. Test Lambda Functions Manually

```bash
# Create test event
cat > test-event.json << EOF
{
  "Records": [
    {
      "kinesis": {
        "data": "eyJ0ZXN0IjogInZhbHVlIn0=",
        "sequenceNumber": "123",
        "partitionKey": "test"
      }
    }
  ]
}
EOF

# Invoke function
aws lambda invoke \
  --function-name YOUR_FUNCTION_NAME \
  --payload file://test-event.json \
  response.json

# Check response
cat response.json
```

### 3. Check Dead Letter Queues

```bash
# Get DLQ messages
aws sqs receive-message \
  --queue-url YOUR_DLQ_URL \
  --max-number-of-messages 10
```

### 4. Verify Data Flow

```bash
# Check Kinesis stream
aws kinesis describe-stream --stream-name YOUR_STREAM_NAME

# Check S3 objects
aws s3 ls s3://YOUR_BUCKET/raw/ --recursive

# Check DynamoDB items
aws dynamodb scan --table-name YOUR_TABLE_NAME --limit 5
```

### 5. Monitor Resource Usage

```bash
# Lambda concurrent executions
aws cloudwatch get-metric-statistics \
  --namespace AWS/Lambda \
  --metric-name ConcurrentExecutions \
  --dimensions Name=FunctionName,Value=YOUR_FUNCTION \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Maximum

# Kinesis iterator age
aws cloudwatch get-metric-statistics \
  --namespace AWS/Kinesis \
  --metric-name GetRecords.IteratorAgeMilliseconds \
  --dimensions Name=StreamName,Value=YOUR_STREAM \
  --start-time $(date -u -v-1H +%Y-%m-%dT%H:%M:%S) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
  --period 300 \
  --statistics Maximum
```

## Performance Optimization

### Slow Processing

**Symptoms:**
- High latency
- Growing backlog

**Solutions:**
1. Increase Lambda memory (also increases CPU)
2. Increase Kinesis shard count
3. Optimize Lambda code
4. Increase batch size
5. Enable parallel processing

### High Costs

**Symptoms:**
- Unexpected AWS bills

**Solutions:**
1. Reduce Kinesis shard count when not testing
2. Set S3 lifecycle policies
3. Use DynamoDB on-demand billing
4. Set CloudWatch log retention
5. Delete old data regularly

### Data Loss

**Symptoms:**
- Missing records in S3 or DynamoDB

**Solutions:**
1. Check Dead Letter Queues
2. Review Lambda error logs
3. Verify retry configuration
4. Check data validation logic
5. Enable S3 versioning

## Getting Additional Help

### AWS Support Resources

1. **AWS Documentation:**
   - [Kinesis Developer Guide](https://docs.aws.amazon.com/kinesis/)
   - [Lambda Developer Guide](https://docs.aws.amazon.com/lambda/)
   - [S3 User Guide](https://docs.aws.amazon.com/s3/)

2. **AWS Support:**
   - Basic support included with all accounts
   - Developer/Business support for faster response

3. **AWS Forums:**
   - [AWS re:Post](https://repost.aws/)
   - Stack Overflow (tag: amazon-web-services)

### Useful Commands

```bash
# Get all CloudWatch alarms in ALARM state
aws cloudwatch describe-alarms --state-value ALARM

# Get Lambda function configuration
aws lambda get-function-configuration --function-name YOUR_FUNCTION

# Get Kinesis stream metrics
aws kinesis describe-stream-summary --stream-name YOUR_STREAM

# Check S3 bucket size
aws s3 ls s3://YOUR_BUCKET --recursive --summarize

# Export DynamoDB table
aws dynamodb scan --table-name YOUR_TABLE > table-export.json
```

### Emergency Procedures

#### Stop All Processing

```bash
# Disable event source mapping
aws lambda update-event-source-mapping \
  --uuid YOUR_MAPPING_UUID \
  --no-enabled

# Or delete the mapping
aws lambda delete-event-source-mapping \
  --uuid YOUR_MAPPING_UUID
```

#### Clear Kinesis Stream

```bash
# Get shard iterator at LATEST position
aws kinesis get-shard-iterator \
  --stream-name YOUR_STREAM \
  --shard-id shardId-000000000000 \
  --shard-iterator-type LATEST
```

#### Emergency Cleanup

```bash
# Run cleanup script
cd scripts
./cleanup.sh

# Or manual cleanup
terraform destroy -auto-approve
```

## Contact

For project-specific issues, refer to the main README.md or create an issue in the repository.
