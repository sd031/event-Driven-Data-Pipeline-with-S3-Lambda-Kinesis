"""
S3 Event Transformer Lambda Function
Triggered by S3 PUT events, transforms and enriches data
"""

import json
import boto3
import os
from datetime import datetime
from typing import Dict, List, Any
import logging
from urllib.parse import unquote_plus
import hashlib

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Initialize AWS clients
s3_client = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')

# Environment variables
PROCESSED_BUCKET = os.environ.get('PROCESSED_BUCKET_NAME')
METADATA_TABLE = os.environ.get('METADATA_TABLE_NAME')

# Get DynamoDB table
metadata_table = dynamodb.Table(METADATA_TABLE) if METADATA_TABLE else None


class DataTransformer:
    """Transforms and enriches data records"""
    
    @staticmethod
    def transform_record(record: Dict[str, Any]) -> Dict[str, Any]:
        """
        Transform a single record with enrichment
        """
        try:
            transformed = {
                # Original data
                'original_data': record.get('data', {}),
                'event_type': record.get('event_type'),
                'original_timestamp': record.get('timestamp'),
                
                # Enriched fields
                'processed_timestamp': datetime.utcnow().isoformat(),
                'record_id': DataTransformer._generate_record_id(record),
                
                # Computed fields
                'metadata': {
                    'source': 'kinesis-stream',
                    'processing_stage': 'transformed',
                    'version': '1.0'
                }
            }
            
            # Add event-specific transformations
            if record.get('event_type') == 'transaction':
                transformed['enriched_data'] = DataTransformer._enrich_transaction(record)
            elif record.get('event_type') == 'user_action':
                transformed['enriched_data'] = DataTransformer._enrich_user_action(record)
            elif record.get('event_type') == 'metric':
                transformed['enriched_data'] = DataTransformer._enrich_metric(record)
            else:
                transformed['enriched_data'] = record.get('data', {})
            
            # Add Kinesis metadata if present
            if 'kinesis_metadata' in record:
                transformed['kinesis_metadata'] = record['kinesis_metadata']
            
            return transformed
            
        except Exception as e:
            logger.error(f"Error transforming record: {e}")
            raise
    
    @staticmethod
    def _generate_record_id(record: Dict) -> str:
        """Generate unique record ID"""
        content = json.dumps(record, sort_keys=True)
        return hashlib.sha256(content.encode()).hexdigest()[:16]
    
    @staticmethod
    def _enrich_transaction(record: Dict) -> Dict:
        """Enrich transaction events"""
        data = record.get('data', {})
        return {
            **data,
            'transaction_date': datetime.utcnow().strftime('%Y-%m-%d'),
            'amount_category': DataTransformer._categorize_amount(data.get('amount', 0)),
            'is_high_value': data.get('amount', 0) > 1000
        }
    
    @staticmethod
    def _enrich_user_action(record: Dict) -> Dict:
        """Enrich user action events"""
        data = record.get('data', {})
        return {
            **data,
            'action_date': datetime.utcnow().strftime('%Y-%m-%d'),
            'session_duration_category': DataTransformer._categorize_duration(
                data.get('session_duration', 0)
            )
        }
    
    @staticmethod
    def _enrich_metric(record: Dict) -> Dict:
        """Enrich metric events"""
        data = record.get('data', {})
        value = data.get('value', 0)
        return {
            **data,
            'metric_date': datetime.utcnow().strftime('%Y-%m-%d'),
            'value_range': DataTransformer._categorize_metric_value(value),
            'is_anomaly': DataTransformer._detect_anomaly(value)
        }
    
    @staticmethod
    def _categorize_amount(amount: float) -> str:
        """Categorize transaction amount"""
        if amount < 10:
            return 'micro'
        elif amount < 100:
            return 'small'
        elif amount < 1000:
            return 'medium'
        else:
            return 'large'
    
    @staticmethod
    def _categorize_duration(duration: int) -> str:
        """Categorize session duration in seconds"""
        if duration < 60:
            return 'short'
        elif duration < 600:
            return 'medium'
        else:
            return 'long'
    
    @staticmethod
    def _categorize_metric_value(value: float) -> str:
        """Categorize metric value"""
        if value < 0:
            return 'negative'
        elif value < 50:
            return 'low'
        elif value < 100:
            return 'normal'
        else:
            return 'high'
    
    @staticmethod
    def _detect_anomaly(value: float) -> bool:
        """Simple anomaly detection"""
        # Simplified: flag values outside typical range
        return value < 0 or value > 200


class S3Handler:
    """Handles S3 operations"""
    
    @staticmethod
    def read_s3_object(bucket: str, key: str) -> List[Dict]:
        """Read and parse JSON lines from S3"""
        try:
            response = s3_client.get_object(Bucket=bucket, Key=key)
            content = response['Body'].read().decode('utf-8')
            
            # Parse JSON lines
            records = []
            for line in content.strip().split('\n'):
                if line:
                    records.append(json.loads(line))
            
            return records
            
        except Exception as e:
            logger.error(f"Error reading S3 object {bucket}/{key}: {e}")
            raise
    
    @staticmethod
    def write_transformed_data(records: List[Dict], original_key: str, bucket: str) -> str:
        """Write transformed data to S3"""
        try:
            # Generate new key in processed bucket
            # Maintain similar partitioning structure
            key_parts = original_key.replace('raw/', 'processed/')
            timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S_%f')
            new_key = key_parts.replace('.json', f'_transformed_{timestamp}.json')
            
            # Prepare data
            data = '\n'.join([json.dumps(r) for r in records])
            
            # Write to S3
            s3_client.put_object(
                Bucket=bucket,
                Key=new_key,
                Body=data.encode('utf-8'),
                ContentType='application/json',
                Metadata={
                    'record_count': str(len(records)),
                    'source_key': original_key,
                    'transformed_at': datetime.utcnow().isoformat(),
                    'transformation_version': '1.0'
                }
            )
            
            logger.info(f"Written {len(records)} transformed records to {new_key}")
            return new_key
            
        except Exception as e:
            logger.error(f"Error writing transformed data: {e}")
            raise


class TransformationMetadata:
    """Tracks transformation metadata"""
    
    @staticmethod
    def save_transformation_metadata(source_key: str, dest_key: str, 
                                     record_count: int, request_id: str):
        """Save transformation metadata to DynamoDB"""
        if not metadata_table:
            logger.warning("Metadata table not configured")
            return
        
        try:
            processed_at = datetime.utcnow().isoformat()
            # Extract shard identifier from source key for tracking
            shard_id = source_key.split('/')[0] if '/' in source_key else 'unknown'
            
            metadata_table.put_item(
                Item={
                    'batch_id': request_id,
                    'processed_at': processed_at,
                    'shard_id': shard_id,
                    'source_key': source_key,
                    'destination_key': dest_key,
                    'record_count': record_count,
                    'transformation_type': 'enrich_and_transform',
                    'processing_stage': 's3_transformation',
                    'ttl': int(datetime.utcnow().timestamp()) + (30 * 24 * 60 * 60)
                }
            )
            logger.info(f"Successfully saved transformation metadata for batch {request_id}, records: {record_count}")
        except Exception as e:
            logger.error(f"Error saving transformation metadata: {e}")


def lambda_handler(event: Dict, context: Any) -> Dict:
    """
    Main Lambda handler for S3 event processing
    
    Args:
        event: S3 event containing object information
        context: Lambda context object
    
    Returns:
        Response with processing statistics
    """
    logger.info(f"S3 Transformer: Processing {len(event['Records'])} S3 event records")
    
    processed_count = 0
    failed_count = 0
    
    # Process each S3 record
    for record in event['Records']:
        try:
            # Get bucket and key from event
            bucket = record['s3']['bucket']['name']
            key = unquote_plus(record['s3']['object']['key'])
            
            logger.info(f"Processing file: s3://{bucket}/{key}")
            
            # Skip if not in raw/ prefix or not JSON
            if not key.startswith('raw/') or not key.endswith('.json'):
                logger.info(f"Skipping file {key} (not in raw/ or not JSON)")
                continue
            
            # Read source data
            records = S3Handler.read_s3_object(bucket, key)
            logger.info(f"Transformation: Read {len(records)} records from {key}")
            
            # Transform records
            transformed_records = []
            for rec in records:
                try:
                    transformed = DataTransformer.transform_record(rec)
                    transformed_records.append(transformed)
                except Exception as e:
                    logger.error(f"Error transforming individual record: {e}")
                    failed_count += 1
            
            # Write transformed data
            if transformed_records and PROCESSED_BUCKET:
                dest_key = S3Handler.write_transformed_data(
                    transformed_records,
                    key,
                    PROCESSED_BUCKET
                )
                
                # Save metadata
                TransformationMetadata.save_transformation_metadata(
                    f"{bucket}/{key}",
                    f"{PROCESSED_BUCKET}/{dest_key}",
                    len(transformed_records),
                    context.aws_request_id
                )
                
                processed_count += len(transformed_records)
            else:
                logger.warning("No records to transform or PROCESSED_BUCKET not configured")
            
        except Exception as e:
            logger.error(f"Error processing S3 record: {e}")
            failed_count += 1
    
    # Prepare response
    response = {
        'statusCode': 200,
        'body': {
            'processed_records': processed_count,
            'failed_records': failed_count,
            'total_s3_events': len(event['Records'])
        }
    }
    
    logger.info(f"Transformation complete: Success={processed_count}, Failed={failed_count}")
    
    return response
