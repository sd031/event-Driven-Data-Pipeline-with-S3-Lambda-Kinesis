# Python Environment Setup

## Issue: ModuleNotFoundError

If you see this error:
```
ModuleNotFoundError: No module named 'boto3'
```

This means Python dependencies are not installed. Your macOS system uses an externally-managed Python environment that requires using a virtual environment.

## Solution: Use Virtual Environment

### Quick Setup (Recommended)

Run the automated setup script:

```bash
./setup_python_env.sh
```

This will:
1. ✅ Create a virtual environment (`venv/`)
2. ✅ Install all Python dependencies
3. ✅ Activate the environment

### Manual Setup

If you prefer to set up manually:

```bash
# 1. Create virtual environment
python3 -m venv venv

# 2. Activate virtual environment
source venv/bin/activate

# 3. Upgrade pip
pip install --upgrade pip

# 4. Install dependencies
pip install -r data-producer/requirements.txt
```

## Using the Virtual Environment

### Activate (Before Running Scripts)

```bash
source venv/bin/activate
```

You'll see `(venv)` in your terminal prompt when activated.

### Run Your Scripts

```bash
# Run data producer
cd data-producer
python3 producer.py --config config.yaml

# Run tests
cd ../scripts
./test-pipeline.sh
```

### Deactivate (When Done)

```bash
deactivate
```

## Troubleshooting

### Issue: "externally-managed-environment" Error

**Error:**
```
error: externally-managed-environment
```

**Solution:**
Use a virtual environment (see above). This is a macOS security feature.

### Issue: Virtual Environment Not Found

**Error:**
```
source: no such file or directory: venv/bin/activate
```

**Solution:**
```bash
# Create the virtual environment first
python3 -m venv venv

# Then activate
source venv/bin/activate
```

### Issue: pip Command Not Found

**Error:**
```
pip: command not found
```

**Solution:**
```bash
# Use pip3 instead
pip3 install -r requirements.txt

# Or ensure virtual environment is activated
source venv/bin/activate
pip install -r requirements.txt
```

### Issue: Permission Denied

**Error:**
```
PermissionError: [Errno 13] Permission denied
```

**Solution:**
```bash
# Make setup script executable
chmod +x setup_python_env.sh

# Run it
./setup_python_env.sh
```

## Dependencies

### Data Producer (`data-producer/requirements.txt`)
- `boto3==1.34.51` - AWS SDK for Python
- `botocore==1.34.51` - Low-level AWS SDK
- `PyYAML==6.0.1` - YAML configuration parser

## Best Practices

### 1. Always Use Virtual Environment

✅ **Do:**
```bash
source venv/bin/activate
python3 producer.py
```

❌ **Don't:**
```bash
python3 producer.py  # Without activating venv
```

### 2. Check If Environment Is Active

```bash
# Check if venv is active
which python3

# Should show: /path/to/project/venv/bin/python3
```

### 3. Update Dependencies

```bash
# Activate venv first
source venv/bin/activate

# Update specific package
pip install --upgrade boto3

# Update all packages
pip install --upgrade -r requirements.txt
```

### 4. Freeze Dependencies

If you add new packages:

```bash
# Activate venv
source venv/bin/activate

# Install new package
pip install new-package

# Update requirements.txt
pip freeze > requirements.txt
```

## Quick Reference

### One-Time Setup
```bash
./setup_python_env.sh
```

### Every Time You Work on the Project
```bash
# Activate environment
source venv/bin/activate

# Do your work...
python3 producer.py

# Deactivate when done
deactivate
```

### Verify Installation
```bash
# Activate venv
source venv/bin/activate

# Check installed packages
pip list

# Should see: boto3, botocore, PyYAML, etc.
```

## Integration with Scripts

The test and deployment scripts should work automatically once the virtual environment is set up, as they call `python3` which will use the venv Python when activated.

### Option 1: Activate Before Running Scripts
```bash
source venv/bin/activate
cd scripts
./test-pipeline.sh
```

### Option 2: Update Scripts to Auto-Activate

You can modify scripts to activate venv automatically. Example:

```bash
#!/bin/bash

# Activate venv if it exists
if [ -f "../venv/bin/activate" ]; then
    source ../venv/bin/activate
fi

# Rest of script...
```

## Alternative: System-Wide Installation (Not Recommended)

If you really want to install system-wide (not recommended):

```bash
pip3 install --break-system-packages -r requirements.txt
```

⚠️ **Warning:** This can break your system Python installation. Use virtual environment instead.

## Summary

✅ **Recommended Workflow:**

1. Run setup once: `./setup_python_env.sh`
2. Activate before work: `source venv/bin/activate`
3. Run your scripts: `python3 producer.py`
4. Deactivate when done: `deactivate`

This keeps your system Python clean and your project dependencies isolated!
