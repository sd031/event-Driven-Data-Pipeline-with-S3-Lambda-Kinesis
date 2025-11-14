#!/bin/bash

# Setup Python Virtual Environment for the Project
# This script creates a virtual environment and installs all dependencies

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Python Environment Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if Python 3 is installed
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: Python 3 is not installed${NC}"
    exit 1
fi

PYTHON_VERSION=$(python3 --version)
echo -e "${GREEN}✓ Found: $PYTHON_VERSION${NC}"
echo ""

# Create virtual environment if it doesn't exist
VENV_DIR="venv"

if [ -d "$VENV_DIR" ]; then
    echo -e "${YELLOW}Virtual environment already exists${NC}"
else
    echo -e "${YELLOW}Creating virtual environment...${NC}"
    python3 -m venv $VENV_DIR
    echo -e "${GREEN}✓ Virtual environment created${NC}"
fi

echo ""
echo -e "${YELLOW}Activating virtual environment...${NC}"
source $VENV_DIR/bin/activate

echo -e "${GREEN}✓ Virtual environment activated${NC}"
echo ""

# Upgrade pip
echo -e "${YELLOW}Upgrading pip...${NC}"
pip install --upgrade pip > /dev/null 2>&1
echo -e "${GREEN}✓ pip upgraded${NC}"
echo ""

# Install data producer dependencies
echo -e "${YELLOW}Installing data producer dependencies...${NC}"
pip install -r data-producer/requirements.txt
echo -e "${GREEN}✓ Data producer dependencies installed${NC}"
echo ""

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Virtual environment is ready at: $VENV_DIR"
echo ""
echo -e "${YELLOW}To activate the virtual environment in the future:${NC}"
echo "  source venv/bin/activate"
echo ""
echo -e "${YELLOW}To deactivate when done:${NC}"
echo "  deactivate"
echo ""
echo -e "${YELLOW}Now you can run:${NC}"
echo "  cd data-producer"
echo "  python3 producer.py --config config.yaml"
echo ""
echo "  Or run the test pipeline:"
echo "  cd scripts"
echo "  ./test-pipeline.sh"
echo ""
