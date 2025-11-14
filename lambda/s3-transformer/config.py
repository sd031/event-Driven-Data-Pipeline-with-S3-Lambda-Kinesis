"""
Configuration for S3 Transformer Lambda
"""

# Transformation settings
ENABLE_ENRICHMENT = True
TRANSFORMATION_VERSION = "1.0"

# Event type specific settings
TRANSACTION_HIGH_VALUE_THRESHOLD = 1000
SESSION_LONG_DURATION_THRESHOLD = 600  # seconds
METRIC_ANOMALY_THRESHOLD = 200

# S3 settings
PROCESSED_PREFIX = "processed/"
FILE_SUFFIX = "_transformed"

# DynamoDB settings
METADATA_TTL_DAYS = 30

# Logging settings
LOG_LEVEL = "INFO"
LOG_TRANSFORMATION_DETAILS = True
