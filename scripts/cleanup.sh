#!/bin/bash

# Cleanup Script
# Destroys all infrastructure to avoid AWS charges

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TERRAFORM_DIR="../infrastructure/terraform"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}Pipeline Cleanup${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

echo -e "${RED}WARNING: This will destroy all infrastructure!${NC}"
echo -e "${RED}This action cannot be undone.${NC}"
echo ""

read -p "Are you sure you want to continue? (type 'yes' to confirm): " confirm
if [ "$confirm" != "yes" ]; then
    echo -e "${GREEN}Cleanup cancelled${NC}"
    exit 0
fi

cd "$TERRAFORM_DIR"

# Get resource names before destroying
if [ -f "outputs.json" ]; then
    RAW_BUCKET=$(terraform output -raw raw_bucket_name 2>/dev/null || echo "")
    PROCESSED_BUCKET=$(terraform output -raw processed_bucket_name 2>/dev/null || echo "")
    
    # Empty S3 buckets before destroying
    if [ -n "$RAW_BUCKET" ]; then
        echo -e "${YELLOW}Emptying raw bucket: $RAW_BUCKET${NC}"
        aws s3 rm s3://$RAW_BUCKET --recursive 2>/dev/null || true
        
        # Delete all versions if versioning is enabled
        aws s3api list-object-versions \
            --bucket "$RAW_BUCKET" \
            --query 'Versions[].{Key:Key,VersionId:VersionId}' \
            --output json 2>/dev/null | \
        jq -r '.[] | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' | \
        xargs -I {} aws s3api delete-object --bucket "$RAW_BUCKET" {} 2>/dev/null || true
        
        echo -e "${GREEN}✓ Raw bucket emptied${NC}"
    fi
    
    if [ -n "$PROCESSED_BUCKET" ]; then
        echo -e "${YELLOW}Emptying processed bucket: $PROCESSED_BUCKET${NC}"
        aws s3 rm s3://$PROCESSED_BUCKET --recursive 2>/dev/null || true
        
        # Delete all versions if versioning is enabled
        aws s3api list-object-versions \
            --bucket "$PROCESSED_BUCKET" \
            --query 'Versions[].{Key:Key,VersionId:VersionId}' \
            --output json 2>/dev/null | \
        jq -r '.[] | "--key \"\(.Key)\" --version-id \"\(.VersionId)\""' | \
        xargs -I {} aws s3api delete-object --bucket "$PROCESSED_BUCKET" {} 2>/dev/null || true
        
        echo -e "${GREEN}✓ Processed bucket emptied${NC}"
    fi
fi

echo ""
echo -e "${YELLOW}Destroying infrastructure with Terraform...${NC}"

# Destroy infrastructure
terraform destroy -auto-approve

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Cleanup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "All resources have been destroyed."
echo "You will no longer incur charges for this infrastructure."
echo ""

# Clean up local files
cd ../../scripts
echo -e "${YELLOW}Cleaning up local files...${NC}"

rm -f "$TERRAFORM_DIR/outputs.json"
rm -f "$TERRAFORM_DIR/tfplan"
rm -f "$TERRAFORM_DIR/.terraform.lock.hcl"
rm -rf "$TERRAFORM_DIR/.terraform"

# Clean up Lambda deployment packages
rm -f ../lambda/kinesis-processor.zip
rm -f ../lambda/s3-transformer.zip

echo -e "${GREEN}✓ Local files cleaned${NC}"
echo ""
