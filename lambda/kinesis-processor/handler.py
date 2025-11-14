"""
Kinesis Stream Processor Lambda Function
Processes records from Kinesis Data Stream, validates data, and stores in S3
"""

import json
import base64
import boto3
import os
from datetime import datetime
from typing import Dict, List, Any
import logging
from decimal import Decimal

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

# Environment variables
RAW_BUCKET = os.environ.get('RAW_BUCKET_NAME')
METADATA_TABLE = os.environ.get('METADATA_TABLE_NAME')
ENABLE_VALIDATION = os.environ.get('ENABLE_VALIDATION', 'true').lower() == 'true'

# Get DynamoDB table
metadata_table = dynamodb.Table(METADATA_TABLE) if METADATA_TABLE else None


class DataValidator:
    """Validates incoming data records"""
    
    @staticmethod
    def validate_record(record: Dict[str, Any]) -> tuple[bool, str]:
        """
        Validate a single record
        Returns: (is_valid, error_message)
        """
        try:
            # Check required fields
            required_fields = ['timestamp', 'event_type', 'data']
            for field in required_fields:
                if field not in record:
                    return False, f"Missing required field: {field}"
            
            # Validate timestamp format
            try:
                datetime.fromisoformat(record['timestamp'].replace('Z', '+00:00'))
            except (ValueError, AttributeError):
                return False, "Invalid timestamp format"
            
            # Validate event_type
            valid_event_types = ['user_action', 'system_event', 'transaction', 'metric']
            if record['event_type'] not in valid_event_types:
                return False, f"Invalid event_type: {record['event_type']}"
            
            return True, ""
            
        except Exception as e:
            return False, f"Validation error: {str(e)}"


class S3Writer:
    """Handles writing data to S3 with partitioning"""
    
    @staticmethod
    def get_partition_path(timestamp: str, event_type: str) -> str:
        """Generate S3 partition path based on timestamp and event type"""
        dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
        return f"event_type={event_type}/year={dt.year}/month={dt.month:02d}/day={dt.day:02d}/hour={dt.hour:02d}"
    
    @staticmethod
    def write_batch(records: List[Dict], bucket: str) -> Dict[str, int]:
        """
        Write batch of records to S3 with partitioning
        Returns: Statistics about written records
        """
        stats = {
            'total': 0,
            'success': 0,
            'failed': 0,
            'partitions': set()
        }
        
        # Group records by partition
        partitioned_records = {}
        for record in records:
            try:
                partition = S3Writer.get_partition_path(
                    record['timestamp'],
                    record['event_type']
                )
                if partition not in partitioned_records:
                    partitioned_records[partition] = []
                partitioned_records[partition].append(record)
                stats['partitions'].add(partition)
            except Exception as e:
                logger.error(f"Error partitioning record: {e}")
                stats['failed'] += 1
        
        # Write each partition
        for partition, partition_records in partitioned_records.items():
            try:
                # Create unique filename
                timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S_%f')
                key = f"raw/{partition}/data_{timestamp}.json"
                
                # Prepare data
                data = '\n'.join([json.dumps(r) for r in partition_records])
                
                # Write to S3
                s3_client.put_object(
                    Bucket=bucket,
                    Key=key,
                    Body=data.encode('utf-8'),
                    ContentType='application/json',
                    Metadata={
                        'record_count': str(len(partition_records)),
                        'partition': partition,
                        'processed_at': datetime.utcnow().isoformat()
                    }
                )
                
                stats['success'] += len(partition_records)
                logger.info(f"Processing success: Written {len(partition_records)} records to s3://{bucket}/{key}")
                
            except Exception as e:
                logger.error(f"Error writing partition {partition}: {e}")
                stats['failed'] += len(partition_records)
        
        stats['total'] = stats['success'] + stats['failed']
        stats['partitions'] = len(stats['partitions'])
        
        return stats


class MetadataTracker:
    """Tracks processing metadata in DynamoDB"""
    
    @staticmethod
    def save_batch_metadata(batch_id: str, stats: Dict, shard_id: str):
        """Save batch processing metadata"""
        if not metadata_table:
            logger.warning("Metadata table not configured")
            return
        
        try:
            metadata_table.put_item(
                Item={
                    'batch_id': batch_id,
                    'shard_id': shard_id,
                    'processed_at': datetime.utcnow().isoformat(),
                    'total_records': stats['total'],
                    'success_records': stats['success'],
                    'failed_records': stats['failed'],
                    'partitions_count': stats['partitions'],
                    'ttl': int(datetime.utcnow().timestamp()) + (30 * 24 * 60 * 60)  # 30 days TTL
                }
            )
            logger.info(f"Processing success: Saved metadata for batch {batch_id}, {stats['success']} records processed")
        except Exception as e:
            logger.error(f"Error saving metadata: {e}")


def process_record(kinesis_record: Dict) -> Dict[str, Any]:
    """
    Process a single Kinesis record
    Returns: Processed record or None if invalid
    """
    try:
        # Decode data
        payload = base64.b64decode(kinesis_record['data']).decode('utf-8')
        record = json.loads(payload)
        
        # Validate if enabled
        if ENABLE_VALIDATION:
            is_valid, error_msg = DataValidator.validate_record(record)
            if not is_valid:
                logger.warning(f"Invalid record: {error_msg}")
                return None
        
        # Add metadata
        record['kinesis_metadata'] = {
            'sequence_number': kinesis_record['sequenceNumber'],
            'partition_key': kinesis_record['partitionKey'],
            'approximate_arrival_timestamp': kinesis_record['approximateArrivalTimestamp']
        }
        
        return record
        
    except json.JSONDecodeError as e:
        logger.error(f"JSON decode error: {e}")
        return None
    except Exception as e:
        logger.error(f"Error processing record: {e}")
        return None


def lambda_handler(event: Dict, context: Any) -> Dict:
    """
    Main Lambda handler for Kinesis stream processing
    
    Args:
        event: Kinesis event containing records
        context: Lambda context object
    
    Returns:
        Response with processing statistics
    """
    logger.info(f"Kinesis Processor: Processing batch with {len(event['Records'])} records")
    
    # Initialize counters
    processed_records = []
    invalid_count = 0
    
    # Process each Kinesis record
    for kinesis_record in event['Records']:
        record_data = kinesis_record['kinesis']
        processed = process_record(record_data)
        
        if processed:
            processed_records.append(processed)
        else:
            invalid_count += 1
    
    # Write valid records to S3
    stats = {'total': 0, 'success': 0, 'failed': 0, 'partitions': 0}
    
    if processed_records and RAW_BUCKET:
        stats = S3Writer.write_batch(processed_records, RAW_BUCKET)
    else:
        logger.warning("No valid records to write or RAW_BUCKET not configured")
    
    # Save metadata
    if event['Records']:
        batch_id = f"{context.aws_request_id}"
        shard_id = event['Records'][0]['eventID'].split(':')[0]
        MetadataTracker.save_batch_metadata(batch_id, stats, shard_id)
    
    # Prepare response
    response = {
        'statusCode': 200,
        'body': {
            'processed': len(processed_records),
            'invalid': invalid_count,
            'written_to_s3': stats['success'],
            'failed_writes': stats['failed'],
            'partitions': stats['partitions']
        }
    }
    
    logger.info(f"Processing complete: Processed={len(processed_records)}, Invalid={invalid_count}, S3_Success={stats['success']}, S3_Failed={stats['failed']}")
    
    return response
