"""
Unit tests for Kinesis Processor Lambda
"""

import unittest
import json
import base64
from unittest.mock import Mock, patch, MagicMock
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from handler import DataValidator, S3Writer, process_record


class TestDataValidator(unittest.TestCase):
    """Test DataValidator class"""
    
    def test_valid_record(self):
        """Test validation of valid record"""
        record = {
            'timestamp': '2024-01-15T10:30:00Z',
            'event_type': 'user_action',
            'data': {'test': 'value'}
        }
        
        is_valid, error = DataValidator.validate_record(record)
        self.assertTrue(is_valid)
        self.assertEqual(error, "")
    
    def test_missing_required_field(self):
        """Test validation fails for missing field"""
        record = {
            'timestamp': '2024-01-15T10:30:00Z',
            'data': {'test': 'value'}
            # Missing event_type
        }
        
        is_valid, error = DataValidator.validate_record(record)
        self.assertFalse(is_valid)
        self.assertIn('event_type', error)
    
    def test_invalid_timestamp(self):
        """Test validation fails for invalid timestamp"""
        record = {
            'timestamp': 'invalid-timestamp',
            'event_type': 'user_action',
            'data': {'test': 'value'}
        }
        
        is_valid, error = DataValidator.validate_record(record)
        self.assertFalse(is_valid)
        self.assertIn('timestamp', error)
    
    def test_invalid_event_type(self):
        """Test validation fails for invalid event type"""
        record = {
            'timestamp': '2024-01-15T10:30:00Z',
            'event_type': 'invalid_type',
            'data': {'test': 'value'}
        }
        
        is_valid, error = DataValidator.validate_record(record)
        self.assertFalse(is_valid)
        self.assertIn('event_type', error)


class TestS3Writer(unittest.TestCase):
    """Test S3Writer class"""
    
    def test_get_partition_path(self):
        """Test partition path generation"""
        timestamp = '2024-01-15T10:30:00Z'
        event_type = 'user_action'
        
        path = S3Writer.get_partition_path(timestamp, event_type)
        
        self.assertIn('event_type=user_action', path)
        self.assertIn('year=2024', path)
        self.assertIn('month=01', path)
        self.assertIn('day=15', path)
        self.assertIn('hour=10', path)


class TestProcessRecord(unittest.TestCase):
    """Test process_record function"""
    
    @patch.dict(os.environ, {'ENABLE_VALIDATION': 'true'})
    def test_process_valid_record(self):
        """Test processing valid Kinesis record"""
        data = {
            'timestamp': '2024-01-15T10:30:00Z',
            'event_type': 'user_action',
            'data': {'test': 'value'}
        }
        
        kinesis_record = {
            'data': base64.b64encode(json.dumps(data).encode()).decode(),
            'sequenceNumber': '123456',
            'partitionKey': 'test-key',
            'approximateArrivalTimestamp': 1234567890
        }
        
        result = process_record(kinesis_record)
        
        self.assertIsNotNone(result)
        self.assertEqual(result['event_type'], 'user_action')
        self.assertIn('kinesis_metadata', result)
    
    @patch.dict(os.environ, {'ENABLE_VALIDATION': 'true'})
    def test_process_invalid_record(self):
        """Test processing invalid Kinesis record"""
        data = {
            'timestamp': '2024-01-15T10:30:00Z',
            # Missing event_type
            'data': {'test': 'value'}
        }
        
        kinesis_record = {
            'data': base64.b64encode(json.dumps(data).encode()).decode(),
            'sequenceNumber': '123456',
            'partitionKey': 'test-key',
            'approximateArrivalTimestamp': 1234567890
        }
        
        result = process_record(kinesis_record)
        
        self.assertIsNone(result)
    
    def test_process_invalid_json(self):
        """Test processing record with invalid JSON"""
        kinesis_record = {
            'data': base64.b64encode(b'invalid json').decode(),
            'sequenceNumber': '123456',
            'partitionKey': 'test-key',
            'approximateArrivalTimestamp': 1234567890
        }
        
        result = process_record(kinesis_record)
        
        self.assertIsNone(result)


if __name__ == '__main__':
    unittest.main()
