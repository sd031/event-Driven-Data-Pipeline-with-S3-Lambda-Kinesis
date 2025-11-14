#!/bin/bash

# Pipeline Testing Script
# Runs end-to-end tests on the pipeline

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

TERRAFORM_DIR="../infrastructure/terraform"
PRODUCER_DIR="../data-producer"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Pipeline End-to-End Test${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if infrastructure is deployed
if [ ! -f "$TERRAFORM_DIR/outputs.json" ]; then
    echo -e "${RED}Error: Infrastructure not deployed. Run deploy.sh first.${NC}"
    exit 1
fi

cd "$TERRAFORM_DIR"

# Get resource names and region
KINESIS_STREAM=$(terraform output -raw kinesis_stream_name)
RAW_BUCKET=$(terraform output -raw raw_bucket_name)
PROCESSED_BUCKET=$(terraform output -raw processed_bucket_name)
METADATA_TABLE=$(terraform output -raw metadata_table_name)
AWS_REGION=$(terraform output -raw aws_region)

cd ../../scripts

echo -e "${BLUE}Testing with resources:${NC}"
echo "  Region: $AWS_REGION"
echo "  Kinesis Stream: $KINESIS_STREAM"
echo "  Raw Bucket: $RAW_BUCKET"
echo "  Processed Bucket: $PROCESSED_BUCKET"
echo ""

# Test 1: Send test data to Kinesis
echo -e "${YELLOW}Test 1: Sending test data to Kinesis...${NC}"

cd "$PRODUCER_DIR"

# Send 50 records at 10 records/sec
python3 producer.py \
    --stream "$KINESIS_STREAM" \
    --region "$AWS_REGION" \
    --rate 10 \
    --duration 5 \
    --batch-size 10

echo -e "${GREEN}✓ Test data sent${NC}"
echo ""

cd ../scripts

# Test 2: Wait for processing
echo -e "${YELLOW}Test 2: Waiting for Lambda processing (30 seconds)...${NC}"
sleep 30
echo -e "${GREEN}✓ Wait complete${NC}"
echo ""

# Test 3: Check raw data in S3
echo -e "${YELLOW}Test 3: Checking raw data in S3...${NC}"

RAW_COUNT=$(aws s3 ls s3://$RAW_BUCKET/raw/ --recursive --region $AWS_REGION | wc -l)
echo "  Raw files found: $RAW_COUNT"

if [ "$RAW_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Raw data found in S3${NC}"
    
    # Show sample file
    SAMPLE_FILE=$(aws s3 ls s3://$RAW_BUCKET/raw/ --recursive --region $AWS_REGION | head -1 | awk '{print $4}')
    if [ -n "$SAMPLE_FILE" ]; then
        echo ""
        echo -e "${BLUE}Sample raw file: $SAMPLE_FILE${NC}"
        (aws s3 cp s3://$RAW_BUCKET/$SAMPLE_FILE - --region $AWS_REGION 2>/dev/null | head -3) 2>/dev/null || true
    fi
else
    echo -e "${RED}✗ No raw data found${NC}"
fi
echo ""

# Test 4: Wait for S3 transformer
echo -e "${YELLOW}Test 4: Waiting for S3 transformer (30 seconds)...${NC}"
sleep 30
echo -e "${GREEN}✓ Wait complete${NC}"
echo ""

# Test 5: Check processed data in S3
echo -e "${YELLOW}Test 5: Checking processed data in S3...${NC}"

PROCESSED_COUNT=$(aws s3 ls s3://$PROCESSED_BUCKET/processed/ --recursive --region $AWS_REGION | wc -l)
echo "  Processed files found: $PROCESSED_COUNT"

if [ "$PROCESSED_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Processed data found in S3${NC}"
    
    # Show sample file
    SAMPLE_FILE=$(aws s3 ls s3://$PROCESSED_BUCKET/processed/ --recursive --region $AWS_REGION | head -1 | awk '{print $4}')
    if [ -n "$SAMPLE_FILE" ]; then
        echo ""
        echo -e "${BLUE}Sample processed file: $SAMPLE_FILE${NC}"
        (aws s3 cp s3://$PROCESSED_BUCKET/$SAMPLE_FILE - --region $AWS_REGION 2>/dev/null | head -3) 2>/dev/null || true
    fi
else
    echo -e "${RED}✗ No processed data found${NC}"
fi
echo ""

# Test 6: Check DynamoDB metadata
echo -e "${YELLOW}Test 6: Checking DynamoDB metadata...${NC}"

METADATA_COUNT=$(aws dynamodb scan \
    --table-name "$METADATA_TABLE" \
    --select COUNT \
    --query 'Count' \
    --output text \
    --region $AWS_REGION 2>/dev/null || echo "0")

echo "  Metadata records: $METADATA_COUNT"

if [ "$METADATA_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ Metadata found in DynamoDB${NC}"
    
    # Show sample record
    echo ""
    echo -e "${BLUE}Sample metadata record:${NC}"
    aws dynamodb scan \
        --table-name "$METADATA_TABLE" \
        --limit 1 \
        --output json \
        --region $AWS_REGION 2>/dev/null | jq '.Items[0]' || true
else
    echo -e "${RED}✗ No metadata found${NC}"
fi
echo ""

# Test 7: Check Lambda logs
echo -e "${YELLOW}Test 7: Checking Lambda execution logs...${NC}"

KINESIS_PROCESSOR=$(cd "$TERRAFORM_DIR" && terraform output -raw kinesis_processor_function_name)
S3_TRANSFORMER=$(cd "$TERRAFORM_DIR" && terraform output -raw s3_transformer_function_name)

echo -e "${BLUE}Kinesis Processor recent logs:${NC}"
aws logs tail /aws/lambda/$KINESIS_PROCESSOR --since 5m --format short --region $AWS_REGION 2>/dev/null | grep -i "processing\|success\|error" | head -5 || echo "  No relevant logs found"
echo ""

echo -e "${BLUE}S3 Transformer recent logs:${NC}"
aws logs tail /aws/lambda/$S3_TRANSFORMER --since 5m --format short --region $AWS_REGION 2>/dev/null | grep -i "transform\|success\|error" | head -5 || echo "  No relevant logs found"
echo ""

# Test Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Test Summary${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

TESTS_PASSED=0
TESTS_TOTAL=3

[ "$RAW_COUNT" -gt 0 ] && ((TESTS_PASSED++))
[ "$PROCESSED_COUNT" -gt 0 ] && ((TESTS_PASSED++))
[ "$METADATA_COUNT" -gt 0 ] && ((TESTS_PASSED++))

echo "Tests Passed: $TESTS_PASSED / $TESTS_TOTAL"
echo ""

if [ "$TESTS_PASSED" -eq "$TESTS_TOTAL" ]; then
    echo -e "${GREEN}✓ All tests passed! Pipeline is working correctly.${NC}"
else
    echo -e "${YELLOW}⚠ Some tests failed. Check the logs for details.${NC}"
fi
echo ""

echo "For detailed monitoring, run:"
echo "  ./monitor.sh"
echo ""
