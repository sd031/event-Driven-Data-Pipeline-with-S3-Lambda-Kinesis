"""
Unit tests for S3 Transformer Lambda
"""

import unittest
import json
from unittest.mock import Mock, patch
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from handler import DataTransformer


class TestDataTransformer(unittest.TestCase):
    """Test DataTransformer class"""
    
    def test_transform_user_action(self):
        """Test transformation of user action event"""
        record = {
            'timestamp': '2024-01-15T10:30:00Z',
            'event_type': 'user_action',
            'event_id': 'test-123',
            'data': {
                'user_id': 'user_1234',
                'action': 'click',
                'session_duration': 300
            }
        }
        
        result = DataTransformer.transform_record(record)
        
        self.assertIn('enriched_data', result)
        self.assertIn('record_id', result)
        self.assertIn('processed_timestamp', result)
        self.assertEqual(result['event_type'], 'user_action')
        self.assertIn('session_duration_category', result['enriched_data'])
    
    def test_transform_transaction(self):
        """Test transformation of transaction event"""
        record = {
            'timestamp': '2024-01-15T10:30:00Z',
            'event_type': 'transaction',
            'event_id': 'test-456',
            'data': {
                'transaction_id': 'txn_123',
                'amount': 1500.00,
                'currency': 'USD'
            }
        }
        
        result = DataTransformer.transform_record(record)
        
        self.assertIn('enriched_data', result)
        self.assertEqual(result['enriched_data']['amount_category'], 'large')
        self.assertTrue(result['enriched_data']['is_high_value'])
    
    def test_transform_metric(self):
        """Test transformation of metric event"""
        record = {
            'timestamp': '2024-01-15T10:30:00Z',
            'event_type': 'metric',
            'event_id': 'test-789',
            'data': {
                'metric_name': 'cpu_usage',
                'value': 250.0,
                'unit': 'percent'
            }
        }
        
        result = DataTransformer.transform_record(record)
        
        self.assertIn('enriched_data', result)
        self.assertEqual(result['enriched_data']['value_range'], 'high')
        self.assertTrue(result['enriched_data']['is_anomaly'])
    
    def test_categorize_amount(self):
        """Test amount categorization"""
        self.assertEqual(DataTransformer._categorize_amount(5), 'micro')
        self.assertEqual(DataTransformer._categorize_amount(50), 'small')
        self.assertEqual(DataTransformer._categorize_amount(500), 'medium')
        self.assertEqual(DataTransformer._categorize_amount(5000), 'large')
    
    def test_categorize_duration(self):
        """Test duration categorization"""
        self.assertEqual(DataTransformer._categorize_duration(30), 'short')
        self.assertEqual(DataTransformer._categorize_duration(300), 'medium')
        self.assertEqual(DataTransformer._categorize_duration(3000), 'long')
    
    def test_detect_anomaly(self):
        """Test anomaly detection"""
        self.assertFalse(DataTransformer._detect_anomaly(50))
        self.assertFalse(DataTransformer._detect_anomaly(100))
        self.assertTrue(DataTransformer._detect_anomaly(-10))
        self.assertTrue(DataTransformer._detect_anomaly(250))
    
    def test_generate_record_id(self):
        """Test record ID generation"""
        record = {
            'timestamp': '2024-01-15T10:30:00Z',
            'event_type': 'test',
            'data': {'test': 'value'}
        }
        
        record_id = DataTransformer._generate_record_id(record)
        
        self.assertIsInstance(record_id, str)
        self.assertEqual(len(record_id), 16)


if __name__ == '__main__':
    unittest.main()
