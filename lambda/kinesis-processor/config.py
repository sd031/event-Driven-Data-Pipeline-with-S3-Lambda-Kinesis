"""
Configuration for Kinesis Processor Lambda
"""

# Validation settings
ENABLE_VALIDATION = True
REQUIRED_FIELDS = ['timestamp', 'event_type', 'data']
VALID_EVENT_TYPES = ['user_action', 'system_event', 'transaction', 'metric']

# S3 settings
S3_PARTITION_FORMAT = "event_type={event_type}/year={year}/month={month:02d}/day={day:02d}/hour={hour:02d}"
S3_FILE_PREFIX = "data_"
S3_FILE_EXTENSION = ".json"

# Batch processing settings
MAX_BATCH_SIZE = 500
BATCH_TIMEOUT_SECONDS = 60

# DynamoDB settings
METADATA_TTL_DAYS = 30

# Logging settings
LOG_LEVEL = "INFO"
LOG_INVALID_RECORDS = True
