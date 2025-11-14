# Contributing to Event-Driven Data Pipeline

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## Getting Started

1. Fork the repository
2. Clone your fork
3. Create a feature branch
4. Make your changes
5. Test your changes
6. Submit a pull request

## Development Setup

### Prerequisites

- AWS Account with appropriate permissions
- AWS CLI configured
- Terraform >= 1.0
- Python 3.9+
- Git

### Local Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/event-driven-pipeline.git
cd event-driven-pipeline

# Install dependencies
cd data-producer
pip install -r requirements.txt

cd ../lambda/kinesis-processor
pip install -r requirements.txt

cd ../s3-transformer
pip install -r requirements.txt
```

## Code Standards

### Python

- Follow PEP 8 style guide
- Use type hints where appropriate
- Write docstrings for all functions and classes
- Keep functions focused and small
- Maximum line length: 100 characters

### Terraform

- Use consistent naming conventions
- Add comments for complex logic
- Use variables for configurable values
- Follow HashiCorp style guide
- Run `terraform fmt` before committing

### Shell Scripts

- Use bash shebang: `#!/bin/bash`
- Set error handling: `set -e`
- Add comments for complex logic
- Use meaningful variable names
- Test on macOS and Linux

## Testing

### Unit Tests

Run unit tests for Lambda functions:

```bash
# Kinesis processor tests
cd lambda/kinesis-processor
python -m pytest tests/

# S3 transformer tests
cd ../s3-transformer
python -m pytest tests/
```

### Integration Tests

```bash
# Deploy infrastructure
cd scripts
./deploy.sh

# Run integration tests
./test-pipeline.sh

# Cleanup
./cleanup.sh
```

### Terraform Validation

```bash
cd infrastructure/terraform
terraform fmt -check
terraform validate
```

## Pull Request Process

1. **Create a Feature Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make Your Changes**
   - Write clear, concise commit messages
   - Keep commits focused and atomic
   - Add tests for new functionality

3. **Test Your Changes**
   - Run unit tests
   - Test manually if needed
   - Verify Terraform changes

4. **Update Documentation**
   - Update README.md if needed
   - Add/update docstrings
   - Update architecture docs if applicable

5. **Submit Pull Request**
   - Provide clear description
   - Reference related issues
   - Include test results
   - Add screenshots if applicable

### PR Title Format

```
[Type] Brief description

Types:
- feat: New feature
- fix: Bug fix
- docs: Documentation changes
- refactor: Code refactoring
- test: Test additions/changes
- chore: Maintenance tasks
```

### PR Description Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings generated
```

## Coding Guidelines

### Lambda Functions

**Structure:**
```python
"""
Module docstring
"""

import standard_library
import third_party
import local_modules

# Constants
CONSTANT_NAME = "value"

# Classes
class MyClass:
    """Class docstring"""
    
    def method(self, param: str) -> bool:
        """Method docstring"""
        pass

# Functions
def my_function(param: str) -> dict:
    """Function docstring"""
    pass

# Handler
def lambda_handler(event: dict, context: Any) -> dict:
    """Lambda handler docstring"""
    pass
```

**Error Handling:**
```python
try:
    # Code that might fail
    result = risky_operation()
except SpecificException as e:
    logger.error(f"Specific error: {e}")
    # Handle specific error
except Exception as e:
    logger.error(f"Unexpected error: {e}")
    # Handle general error
finally:
    # Cleanup if needed
    pass
```

**Logging:**
```python
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Use appropriate log levels
logger.debug("Detailed debug information")
logger.info("General information")
logger.warning("Warning message")
logger.error("Error message")
```

### Terraform

**Resource Naming:**
```hcl
# Use descriptive names
resource "aws_kinesis_stream" "data_stream" {
  name = "${var.project_name}-stream-${var.environment}"
  # ...
}

# Use locals for computed values
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

**Variables:**
```hcl
variable "example_var" {
  description = "Clear description of purpose"
  type        = string
  default     = "default_value"
  
  validation {
    condition     = length(var.example_var) > 0
    error_message = "Variable cannot be empty."
  }
}
```

## Documentation

### Code Comments

```python
# Good: Explains why, not what
# Use exponential backoff to avoid overwhelming the API
time.sleep(2 ** retry_count)

# Bad: States the obvious
# Sleep for 2 seconds
time.sleep(2)
```

### Docstrings

```python
def process_data(data: dict, validate: bool = True) -> dict:
    """
    Process and validate input data.
    
    Args:
        data: Dictionary containing raw data
        validate: Whether to perform validation (default: True)
    
    Returns:
        Dictionary containing processed data
    
    Raises:
        ValueError: If data is invalid and validate=True
    """
    pass
```

## Issue Reporting

### Bug Reports

Include:
- Clear title and description
- Steps to reproduce
- Expected vs actual behavior
- Environment details (OS, versions)
- Relevant logs or screenshots
- Minimal reproducible example

### Feature Requests

Include:
- Clear use case
- Proposed solution
- Alternative solutions considered
- Impact on existing functionality

## Security

### Reporting Security Issues

**DO NOT** create public issues for security vulnerabilities.

Instead:
1. Email security concerns privately
2. Include detailed description
3. Provide steps to reproduce
4. Allow time for fix before disclosure

### Security Best Practices

- Never commit credentials
- Use AWS Secrets Manager for secrets
- Follow least privilege principle
- Enable encryption at rest and in transit
- Keep dependencies updated

## Code Review

### As a Reviewer

- Be respectful and constructive
- Focus on code, not the person
- Explain reasoning for suggestions
- Approve when ready, request changes if needed

### As an Author

- Respond to all comments
- Ask questions if unclear
- Make requested changes or explain why not
- Thank reviewers for their time

## Release Process

1. Update version numbers
2. Update CHANGELOG.md
3. Create release branch
4. Run full test suite
5. Create GitHub release
6. Tag release
7. Deploy to production (if applicable)

## Questions?

- Open an issue for questions
- Check existing issues and PRs
- Review documentation

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

## Thank You!

Your contributions make this project better for everyone. Thank you for taking the time to contribute!
