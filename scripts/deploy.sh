#!/bin/bash

# Event-Driven Pipeline Deployment Script
# This script deploys the entire infrastructure and Lambda functions

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
TERRAFORM_DIR="../infrastructure/terraform"
LAMBDA_DIR="../lambda"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Event-Driven Pipeline Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${NC}"

if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is not installed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All prerequisites met${NC}"
echo ""

# Check AWS credentials
echo -e "${YELLOW}Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    echo "Run: aws configure"
    exit 1
fi

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=$(aws configure get region)
echo -e "${GREEN}✓ AWS Account: ${AWS_ACCOUNT_ID}${NC}"
echo -e "${GREEN}✓ AWS Region: ${AWS_REGION}${NC}"
echo ""

# Install Lambda dependencies
echo -e "${YELLOW}Installing Lambda dependencies...${NC}"

cd "$LAMBDA_DIR/kinesis-processor"
if [ -f "requirements.txt" ]; then
    pip3 install -r requirements.txt -t . --upgrade 2>/dev/null || true
    echo -e "${GREEN}✓ Kinesis processor dependencies installed${NC}"
fi

cd ../s3-transformer
if [ -f "requirements.txt" ]; then
    pip3 install -r requirements.txt -t . --upgrade 2>/dev/null || true
    echo -e "${GREEN}✓ S3 transformer dependencies installed${NC}"
fi

cd ../../scripts
echo ""

# Deploy infrastructure with Terraform
echo -e "${YELLOW}Deploying infrastructure with Terraform...${NC}"
cd "$TERRAFORM_DIR"

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Validate configuration
echo "Validating Terraform configuration..."
terraform validate

# Plan deployment
echo "Planning deployment..."
terraform plan -out=tfplan

# Ask for confirmation
echo ""
read -p "Do you want to apply this plan? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo -e "${YELLOW}Deployment cancelled${NC}"
    exit 0
fi

# Apply configuration
echo "Applying Terraform configuration..."
terraform apply tfplan

# Get outputs
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${YELLOW}Resource Information:${NC}"
terraform output -json > outputs.json

KINESIS_STREAM=$(terraform output -raw kinesis_stream_name)
RAW_BUCKET=$(terraform output -raw raw_bucket_name)
PROCESSED_BUCKET=$(terraform output -raw processed_bucket_name)
METADATA_TABLE=$(terraform output -raw metadata_table_name)

echo "Kinesis Stream: $KINESIS_STREAM"
echo "Raw Bucket: $RAW_BUCKET"
echo "Processed Bucket: $PROCESSED_BUCKET"
echo "Metadata Table: $METADATA_TABLE"
echo ""

# Update producer config
echo -e "${YELLOW}Updating producer configuration...${NC}"
cd ../../data-producer
if [ -f "config.yaml" ]; then
    # Update stream name in config
    sed -i.bak "s/stream_name:.*/stream_name: $KINESIS_STREAM/" config.yaml
    rm -f config.yaml.bak
    echo -e "${GREEN}✓ Producer config updated${NC}"
fi

cd ../scripts
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Next Steps:${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "1. Test the pipeline:"
echo "   cd ../data-producer"
echo "   python3 producer.py --config config.yaml"
echo ""
echo "2. Monitor the pipeline:"
echo "   ./monitor.sh"
echo ""
echo "3. View CloudWatch logs:"
echo "   aws logs tail /aws/lambda/$KINESIS_STREAM --follow"
echo ""
echo "4. Check S3 buckets:"
echo "   aws s3 ls s3://$RAW_BUCKET/raw/"
echo "   aws s3 ls s3://$PROCESSED_BUCKET/processed/"
echo ""
echo -e "${YELLOW}Remember to run './cleanup.sh' when done to avoid charges!${NC}"
echo ""
