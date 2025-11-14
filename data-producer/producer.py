#!/usr/bin/env python3
"""
Kinesis Data Producer
Generates and sends sample data to Kinesis Data Stream
"""

import boto3
import json
import time
import random
import argparse
import yaml
from datetime import datetime, timezone
from typing import Dict, List
import logging
from uuid import uuid4

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class DataGenerator:
    """Generates sample data for different event types"""
    
    EVENT_TYPES = ['user_action', 'transaction', 'metric', 'system_event']
    
    USER_ACTIONS = ['click', 'view', 'purchase', 'login', 'logout', 'search']
    TRANSACTION_TYPES = ['payment', 'refund', 'transfer', 'withdrawal']
    METRIC_NAMES = ['cpu_usage', 'memory_usage', 'disk_io', 'network_latency']
    SYSTEM_EVENTS = ['startup', 'shutdown', 'error', 'warning', 'info']
    
    @staticmethod
    def generate_user_action() -> Dict:
        """Generate user action event"""
        return {
            'user_id': f"user_{random.randint(1000, 9999)}",
            'action': random.choice(DataGenerator.USER_ACTIONS),
            'page': f"/page/{random.randint(1, 10)}",
            'session_duration': random.randint(10, 3600),
            'device': random.choice(['mobile', 'desktop', 'tablet']),
            'browser': random.choice(['chrome', 'firefox', 'safari', 'edge'])
        }
    
    @staticmethod
    def generate_transaction() -> Dict:
        """Generate transaction event"""
        return {
            'transaction_id': str(uuid4()),
            'user_id': f"user_{random.randint(1000, 9999)}",
            'type': random.choice(DataGenerator.TRANSACTION_TYPES),
            'amount': round(random.uniform(1, 5000), 2),
            'currency': random.choice(['USD', 'EUR', 'GBP']),
            'status': random.choice(['completed', 'pending', 'failed']),
            'merchant': f"merchant_{random.randint(1, 100)}"
        }
    
    @staticmethod
    def generate_metric() -> Dict:
        """Generate metric event"""
        return {
            'metric_name': random.choice(DataGenerator.METRIC_NAMES),
            'value': round(random.uniform(0, 100), 2),
            'unit': random.choice(['percent', 'ms', 'bytes', 'count']),
            'host': f"host-{random.randint(1, 50)}",
            'region': random.choice(['us-east-1', 'us-west-2', 'eu-west-1'])
        }
    
    @staticmethod
    def generate_system_event() -> Dict:
        """Generate system event"""
        return {
            'event_name': random.choice(DataGenerator.SYSTEM_EVENTS),
            'service': random.choice(['api', 'database', 'cache', 'queue']),
            'message': f"System event occurred at {datetime.now(timezone.utc).isoformat()}",
            'severity': random.choice(['low', 'medium', 'high', 'critical']),
            'host': f"host-{random.randint(1, 50)}"
        }
    
    @staticmethod
    def generate_event() -> Dict:
        """Generate a random event"""
        event_type = random.choice(DataGenerator.EVENT_TYPES)
        
        if event_type == 'user_action':
            data = DataGenerator.generate_user_action()
        elif event_type == 'transaction':
            data = DataGenerator.generate_transaction()
        elif event_type == 'metric':
            data = DataGenerator.generate_metric()
        else:
            data = DataGenerator.generate_system_event()
        
        return {
            'timestamp': datetime.now(timezone.utc).isoformat().replace('+00:00', 'Z'),
            'event_type': event_type,
            'event_id': str(uuid4()),
            'data': data
        }


class KinesisProducer:
    """Sends data to Kinesis Data Stream"""
    
    def __init__(self, stream_name: str, region: str = 'us-east-1'):
        self.stream_name = stream_name
        self.kinesis_client = boto3.client('kinesis', region_name=region)
        self.stats = {
            'sent': 0,
            'failed': 0,
            'total_bytes': 0
        }
    
    def send_record(self, record: Dict) -> bool:
        """Send a single record to Kinesis"""
        try:
            data = json.dumps(record)
            
            response = self.kinesis_client.put_record(
                StreamName=self.stream_name,
                Data=data,
                PartitionKey=record.get('event_id', str(uuid4()))
            )
            
            self.stats['sent'] += 1
            self.stats['total_bytes'] += len(data.encode('utf-8'))
            
            logger.debug(f"Sent record: {response['SequenceNumber']}")
            return True
            
        except Exception as e:
            logger.error(f"Error sending record: {e}")
            self.stats['failed'] += 1
            return False
    
    def send_batch(self, records: List[Dict]) -> Dict:
        """Send batch of records to Kinesis"""
        try:
            entries = [
                {
                    'Data': json.dumps(record),
                    'PartitionKey': record.get('event_id', str(uuid4()))
                }
                for record in records
            ]
            
            response = self.kinesis_client.put_records(
                StreamName=self.stream_name,
                Records=entries
            )
            
            failed_count = response['FailedRecordCount']
            success_count = len(records) - failed_count
            
            self.stats['sent'] += success_count
            self.stats['failed'] += failed_count
            
            for entry in entries:
                self.stats['total_bytes'] += len(entry['Data'].encode('utf-8'))
            
            logger.info(f"Batch sent: {success_count} success, {failed_count} failed")
            
            return {
                'success': success_count,
                'failed': failed_count
            }
            
        except Exception as e:
            logger.error(f"Error sending batch: {e}")
            self.stats['failed'] += len(records)
            return {
                'success': 0,
                'failed': len(records)
            }
    
    def get_stats(self) -> Dict:
        """Get producer statistics"""
        return {
            **self.stats,
            'success_rate': (
                self.stats['sent'] / (self.stats['sent'] + self.stats['failed']) * 100
                if (self.stats['sent'] + self.stats['failed']) > 0 else 0
            )
        }


def load_config(config_file: str) -> Dict:
    """Load configuration from YAML file"""
    try:
        with open(config_file, 'r') as f:
            return yaml.safe_load(f)
    except Exception as e:
        logger.error(f"Error loading config: {e}")
        return {}


def main():
    parser = argparse.ArgumentParser(description='Kinesis Data Producer')
    parser.add_argument('--stream', type=str, help='Kinesis stream name')
    parser.add_argument('--region', type=str, default='us-east-1', help='AWS region')
    parser.add_argument('--rate', type=int, default=10, help='Records per second')
    parser.add_argument('--duration', type=int, default=60, help='Duration in seconds')
    parser.add_argument('--batch-size', type=int, default=10, help='Batch size for sending')
    parser.add_argument('--config', type=str, help='Path to config file')
    parser.add_argument('--verbose', action='store_true', help='Enable verbose logging')
    
    args = parser.parse_args()
    
    # Set logging level
    if args.verbose:
        logger.setLevel(logging.DEBUG)
    
    # Load config if provided
    config = {}
    if args.config:
        config = load_config(args.config)
    
    # Get stream name from args or config
    stream_name = args.stream or config.get('kinesis', {}).get('stream_name')
    if not stream_name:
        logger.error("Stream name not provided. Use --stream or config file.")
        return
    
    region = args.region or config.get('aws', {}).get('region', 'us-east-1')
    rate = args.rate or config.get('producer', {}).get('rate', 10)
    duration = args.duration or config.get('producer', {}).get('duration', 60)
    batch_size = args.batch_size or config.get('producer', {}).get('batch_size', 10)
    
    logger.info(f"Starting producer for stream: {stream_name}")
    logger.info(f"Rate: {rate} records/sec, Duration: {duration} sec, Batch size: {batch_size}")
    
    # Initialize producer
    producer = KinesisProducer(stream_name, region)
    
    # Calculate timing
    interval = 1.0 / rate if rate > 0 else 1.0
    end_time = time.time() + duration
    
    batch = []
    
    try:
        while time.time() < end_time:
            # Generate event
            event = DataGenerator.generate_event()
            batch.append(event)
            
            # Send batch when full
            if len(batch) >= batch_size:
                producer.send_batch(batch)
                batch = []
            
            # Sleep to maintain rate
            time.sleep(interval)
        
        # Send remaining records
        if batch:
            producer.send_batch(batch)
        
        # Print statistics
        stats = producer.get_stats()
        logger.info("=" * 50)
        logger.info("Producer Statistics:")
        logger.info(f"  Records sent: {stats['sent']}")
        logger.info(f"  Records failed: {stats['failed']}")
        logger.info(f"  Total bytes: {stats['total_bytes']:,}")
        logger.info(f"  Success rate: {stats['success_rate']:.2f}%")
        logger.info("=" * 50)
        
    except KeyboardInterrupt:
        logger.info("Producer stopped by user")
        stats = producer.get_stats()
        logger.info(f"Sent {stats['sent']} records before stopping")
    except Exception as e:
        logger.error(f"Error in producer: {e}")


if __name__ == '__main__':
    main()
