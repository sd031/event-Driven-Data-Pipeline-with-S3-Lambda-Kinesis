#!/bin/bash

# Pipeline Monitoring Script
# Monitors the health and performance of the event-driven pipeline

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TERRAFORM_DIR="../infrastructure/terraform"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Pipeline Monitoring Dashboard${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if Terraform outputs exist
if [ ! -f "$TERRAFORM_DIR/outputs.json" ]; then
    echo -e "${RED}Error: Terraform outputs not found. Run deploy.sh first.${NC}"
    exit 1
fi

cd "$TERRAFORM_DIR"

# Get resource names from Terraform outputs
KINESIS_STREAM=$(terraform output -raw kinesis_stream_name)
RAW_BUCKET=$(terraform output -raw raw_bucket_name)
PROCESSED_BUCKET=$(terraform output -raw processed_bucket_name)
METADATA_TABLE=$(terraform output -raw metadata_table_name)
KINESIS_PROCESSOR=$(terraform output -raw kinesis_processor_function_name)
S3_TRANSFORMER=$(terraform output -raw s3_transformer_function_name)
KINESIS_DLQ=$(terraform output -raw kinesis_processor_dlq_url)
S3_DLQ=$(terraform output -raw s3_transformer_dlq_url)

cd ../../scripts

echo -e "${BLUE}Resource Names:${NC}"
echo "  Kinesis Stream: $KINESIS_STREAM"
echo "  Lambda Processor: $KINESIS_PROCESSOR"
echo "  Lambda Transformer: $S3_TRANSFORMER"
echo ""

# Function to get CloudWatch metrics
get_metric() {
    local namespace=$1
    local metric_name=$2
    local dimensions=$3
    local stat=$4
    
    aws cloudwatch get-metric-statistics \
        --namespace "$namespace" \
        --metric-name "$metric_name" \
        --dimensions "$dimensions" \
        --statistics "$stat" \
        --start-time $(date -u -v-5M +%Y-%m-%dT%H:%M:%S) \
        --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
        --period 300 \
        --query 'Datapoints[0].'"$stat" \
        --output text 2>/dev/null || echo "0"
}

# Monitor Kinesis Stream
echo -e "${YELLOW}Kinesis Stream Metrics (Last 5 minutes):${NC}"

INCOMING_RECORDS=$(get_metric "AWS/Kinesis" "IncomingRecords" "Name=StreamName,Value=$KINESIS_STREAM" "Sum")
INCOMING_BYTES=$(get_metric "AWS/Kinesis" "IncomingBytes" "Name=StreamName,Value=$KINESIS_STREAM" "Sum")
ITERATOR_AGE=$(get_metric "AWS/Kinesis" "GetRecords.IteratorAgeMilliseconds" "Name=StreamName,Value=$KINESIS_STREAM" "Maximum")

echo "  Incoming Records: $INCOMING_RECORDS"
echo "  Incoming Bytes: $INCOMING_BYTES"
echo "  Iterator Age (ms): $ITERATOR_AGE"

if [ "$ITERATOR_AGE" != "0" ] && [ "$ITERATOR_AGE" != "None" ]; then
    if (( $(echo "$ITERATOR_AGE > 60000" | bc -l) )); then
        echo -e "  ${RED}⚠ Warning: High iterator age detected!${NC}"
    fi
fi
echo ""

# Monitor Lambda Functions
echo -e "${YELLOW}Lambda Function Metrics (Last 5 minutes):${NC}"

# Kinesis Processor
echo -e "${BLUE}Kinesis Processor:${NC}"
PROCESSOR_INVOCATIONS=$(get_metric "AWS/Lambda" "Invocations" "Name=FunctionName,Value=$KINESIS_PROCESSOR" "Sum")
PROCESSOR_ERRORS=$(get_metric "AWS/Lambda" "Errors" "Name=FunctionName,Value=$KINESIS_PROCESSOR" "Sum")
PROCESSOR_DURATION=$(get_metric "AWS/Lambda" "Duration" "Name=FunctionName,Value=$KINESIS_PROCESSOR" "Average")
PROCESSOR_THROTTLES=$(get_metric "AWS/Lambda" "Throttles" "Name=FunctionName,Value=$KINESIS_PROCESSOR" "Sum")

echo "  Invocations: $PROCESSOR_INVOCATIONS"
echo "  Errors: $PROCESSOR_ERRORS"
echo "  Avg Duration (ms): $PROCESSOR_DURATION"
echo "  Throttles: $PROCESSOR_THROTTLES"

if [ "$PROCESSOR_ERRORS" != "0" ] && [ "$PROCESSOR_ERRORS" != "None" ]; then
    echo -e "  ${RED}⚠ Errors detected!${NC}"
fi
if [ "$PROCESSOR_THROTTLES" != "0" ] && [ "$PROCESSOR_THROTTLES" != "None" ]; then
    echo -e "  ${RED}⚠ Throttling detected!${NC}"
fi
echo ""

# S3 Transformer
echo -e "${BLUE}S3 Transformer:${NC}"
TRANSFORMER_INVOCATIONS=$(get_metric "AWS/Lambda" "Invocations" "Name=FunctionName,Value=$S3_TRANSFORMER" "Sum")
TRANSFORMER_ERRORS=$(get_metric "AWS/Lambda" "Errors" "Name=FunctionName,Value=$S3_TRANSFORMER" "Sum")
TRANSFORMER_DURATION=$(get_metric "AWS/Lambda" "Duration" "Name=FunctionName,Value=$S3_TRANSFORMER" "Average")

echo "  Invocations: $TRANSFORMER_INVOCATIONS"
echo "  Errors: $TRANSFORMER_ERRORS"
echo "  Avg Duration (ms): $TRANSFORMER_DURATION"

if [ "$TRANSFORMER_ERRORS" != "0" ] && [ "$TRANSFORMER_ERRORS" != "None" ]; then
    echo -e "  ${RED}⚠ Errors detected!${NC}"
fi
echo ""

# Check S3 Buckets
echo -e "${YELLOW}S3 Bucket Status:${NC}"

RAW_OBJECTS=$(aws s3 ls s3://$RAW_BUCKET/raw/ --recursive 2>/dev/null | wc -l || echo "0")
PROCESSED_OBJECTS=$(aws s3 ls s3://$PROCESSED_BUCKET/processed/ --recursive 2>/dev/null | wc -l || echo "0")

echo "  Raw Objects: $RAW_OBJECTS"
echo "  Processed Objects: $PROCESSED_OBJECTS"
echo ""

# Check DynamoDB
echo -e "${YELLOW}DynamoDB Metadata Table:${NC}"

ITEM_COUNT=$(aws dynamodb describe-table \
    --table-name "$METADATA_TABLE" \
    --query 'Table.ItemCount' \
    --output text 2>/dev/null || echo "0")

echo "  Item Count: $ITEM_COUNT"
echo ""

# Check Dead Letter Queues
echo -e "${YELLOW}Dead Letter Queues:${NC}"

KINESIS_DLQ_MESSAGES=$(aws sqs get-queue-attributes \
    --queue-url "$KINESIS_DLQ" \
    --attribute-names ApproximateNumberOfMessages \
    --query 'Attributes.ApproximateNumberOfMessages' \
    --output text 2>/dev/null || echo "0")

S3_DLQ_MESSAGES=$(aws sqs get-queue-attributes \
    --queue-url "$S3_DLQ" \
    --attribute-names ApproximateNumberOfMessages \
    --query 'Attributes.ApproximateNumberOfMessages' \
    --output text 2>/dev/null || echo "0")

echo "  Kinesis Processor DLQ: $KINESIS_DLQ_MESSAGES messages"
echo "  S3 Transformer DLQ: $S3_DLQ_MESSAGES messages"

if [ "$KINESIS_DLQ_MESSAGES" != "0" ]; then
    echo -e "  ${RED}⚠ Messages in Kinesis DLQ!${NC}"
fi
if [ "$S3_DLQ_MESSAGES" != "0" ]; then
    echo -e "  ${RED}⚠ Messages in S3 Transformer DLQ!${NC}"
fi
echo ""

# CloudWatch Alarms
echo -e "${YELLOW}CloudWatch Alarms:${NC}"

ALARMS=$(aws cloudwatch describe-alarms \
    --state-value ALARM \
    --query 'MetricAlarms[*].[AlarmName,StateReason]' \
    --output text 2>/dev/null)

if [ -z "$ALARMS" ]; then
    echo -e "  ${GREEN}✓ No active alarms${NC}"
else
    echo -e "  ${RED}Active Alarms:${NC}"
    echo "$ALARMS" | while read -r line; do
        echo "    - $line"
    done
fi
echo ""

# Recent Lambda Logs
echo -e "${YELLOW}Recent Lambda Logs (Last 10 entries):${NC}"
echo -e "${BLUE}Kinesis Processor:${NC}"
aws logs tail /aws/lambda/$KINESIS_PROCESSOR --since 5m --format short 2>/dev/null | head -10 || echo "  No recent logs"
echo ""

echo -e "${BLUE}S3 Transformer:${NC}"
aws logs tail /aws/lambda/$S3_TRANSFORMER --since 5m --format short 2>/dev/null | head -10 || echo "  No recent logs"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Monitoring Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "To continuously monitor logs, run:"
echo "  aws logs tail /aws/lambda/$KINESIS_PROCESSOR --follow"
echo ""
echo "To view CloudWatch dashboard:"
echo "  https://console.aws.amazon.com/cloudwatch/"
echo ""
