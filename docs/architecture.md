# Architecture Documentation

## System Overview

The Event-Driven Data Pipeline is a serverless, real-time data processing system built on AWS. It demonstrates modern cloud architecture patterns including event-driven design, stream processing, and data lake storage.

## Architecture Diagram

```
┌─────────────────┐
│  Data Producer  │
│   (Python App)  │
└────────┬────────┘
         │
         │ PUT Records
         ▼
┌─────────────────────────────────────────────────────────┐
│                   Amazon Kinesis Data Stream             │
│  • 2 Shards (configurable)                              │
│  • 24-hour retention                                     │
│  • KMS encryption                                        │
└────────┬────────────────────────────────────────────────┘
         │
         │ Event Source Mapping
         │ (Batch: 100 records, 5s window)
         ▼
┌─────────────────────────────────────────────────────────┐
│         Lambda: Kinesis Stream Processor                 │
│  • Validates incoming records                            │
│  • Partitions by event_type and timestamp               │
│  • Writes to S3 raw bucket                              │
│  • Tracks metadata in DynamoDB                          │
└────────┬────────────────────────────────────────────────┘
         │
         │ PUT Object
         ▼
┌─────────────────────────────────────────────────────────┐
│              Amazon S3 - Raw Data Bucket                 │
│  • Partitioned: event_type/year/month/day/hour         │
│  • Versioning enabled                                    │
│  • Lifecycle: Glacier after 90 days                     │
│  • Server-side encryption (AES-256)                     │
└────────┬────────────────────────────────────────────────┘
         │
         │ S3 Event Notification
         │ (ObjectCreated:* on raw/*.json)
         ▼
┌─────────────────────────────────────────────────────────┐
│           Lambda: S3 Data Transformer                    │
│  • Reads raw data from S3                               │
│  • Enriches and transforms records                      │
│  • Adds computed fields                                 │
│  • Writes to S3 processed bucket                        │
└────────┬────────────────────────────────────────────────┘
         │
         │ PUT Object
         ▼
┌─────────────────────────────────────────────────────────┐
│           Amazon S3 - Processed Data Bucket              │
│  • Partitioned: event_type/year/month/day/hour         │
│  • Enriched and transformed data                        │
│  • Ready for analytics                                  │
└─────────────────────────────────────────────────────────┘

         ┌──────────────────────────────────┐
         │     Amazon DynamoDB Table         │
         │  • Stores processing metadata     │
         │  • TTL: 30 days                   │
         │  • On-demand billing              │
         └──────────────────────────────────┘

         ┌──────────────────────────────────┐
         │   Amazon CloudWatch              │
         │  • Lambda logs                    │
         │  • Metrics and alarms             │
         │  • X-Ray tracing                  │
         └──────────────────────────────────┘

         ┌──────────────────────────────────┐
         │   Amazon SQS (DLQ)               │
         │  • Failed Lambda invocations      │
         │  • 14-day retention               │
         └──────────────────────────────────┘
```

## Component Details

### 1. Data Producer

**Purpose:** Generates and sends sample events to Kinesis

**Technology:** Python 3.9+

**Key Features:**
- Configurable event generation rate
- Multiple event types (user_action, transaction, metric, system_event)
- Batch sending for efficiency
- Statistics tracking

**Configuration:**
```yaml
producer:
  rate: 10              # Records per second
  duration: 60          # Duration in seconds
  batch_size: 10        # Records per batch
```

### 2. Amazon Kinesis Data Stream

**Purpose:** Real-time data ingestion and buffering

**Configuration:**
- **Shard Count:** 2 (1 MB/s write, 2 MB/s read per shard)
- **Retention:** 24 hours
- **Encryption:** KMS encryption at rest
- **Monitoring:** Shard-level metrics enabled

**Scaling:**
- Each shard: 1,000 records/sec or 1 MB/sec
- 2 shards = 2,000 records/sec capacity
- Can scale to hundreds of shards

**Cost:** ~$0.015/shard-hour = ~$22/month for 2 shards

### 3. Lambda: Kinesis Stream Processor

**Purpose:** Process streaming data from Kinesis

**Runtime:** Python 3.9

**Configuration:**
- **Memory:** 512 MB (configurable)
- **Timeout:** 60 seconds
- **Concurrency:** Auto-scaling
- **Batch Size:** 100 records
- **Batching Window:** 5 seconds

**Processing Logic:**
1. Decode base64-encoded Kinesis records
2. Parse JSON payload
3. Validate required fields and data types
4. Add Kinesis metadata (sequence number, partition key)
5. Partition data by event_type and timestamp
6. Write to S3 in JSON Lines format
7. Track metadata in DynamoDB

**Error Handling:**
- Retry failed records up to 3 times
- Bisect batch on function error
- Send failed records to DLQ
- Log all errors to CloudWatch

**IAM Permissions:**
- Read from Kinesis stream
- Write to S3 raw bucket
- Write to DynamoDB table
- Decrypt KMS keys
- Write CloudWatch logs
- Send to SQS DLQ

### 4. Amazon S3 - Raw Data Bucket

**Purpose:** Store raw, unprocessed data

**Partitioning Strategy:**
```
s3://bucket/raw/
  event_type=user_action/
    year=2024/
      month=01/
        day=15/
          hour=10/
            data_20240115_103045_123456.json
```

**Benefits:**
- Efficient querying with Athena/Glue
- Easy data lifecycle management
- Organized data structure

**Features:**
- Versioning enabled
- Server-side encryption (AES-256)
- Lifecycle policy: Glacier after 90 days
- Public access blocked
- Event notifications enabled

**Data Format:** JSON Lines (newline-delimited JSON)
```json
{"timestamp":"2024-01-15T10:30:00Z","event_type":"user_action",...}
{"timestamp":"2024-01-15T10:30:01Z","event_type":"transaction",...}
```

### 5. Lambda: S3 Data Transformer

**Purpose:** Transform and enrich raw data

**Runtime:** Python 3.9

**Configuration:**
- **Memory:** 512 MB
- **Timeout:** 60 seconds
- **Trigger:** S3 ObjectCreated events on raw/*.json

**Transformation Logic:**

**For Transactions:**
- Add transaction_date
- Categorize amount (micro/small/medium/large)
- Flag high-value transactions (>$1000)

**For User Actions:**
- Add action_date
- Categorize session duration (short/medium/long)

**For Metrics:**
- Add metric_date
- Categorize value range (negative/low/normal/high)
- Detect anomalies (values outside normal range)

**Enrichment:**
- Generate unique record_id (SHA-256 hash)
- Add processing timestamp
- Add metadata (source, version, stage)
- Preserve original data

**Output Format:**
```json
{
  "original_data": {...},
  "enriched_data": {...},
  "record_id": "abc123...",
  "processed_timestamp": "2024-01-15T10:31:00Z",
  "metadata": {
    "source": "kinesis-stream",
    "processing_stage": "transformed",
    "version": "1.0"
  }
}
```

### 6. Amazon S3 - Processed Data Bucket

**Purpose:** Store transformed, analytics-ready data

**Partitioning:** Same as raw bucket

**Use Cases:**
- Analytics with Athena
- ML model training
- Business intelligence dashboards
- Data exports

### 7. Amazon DynamoDB

**Purpose:** Track processing metadata and state

**Table Schema:**
```
Primary Key: batch_id (String)
Sort Key: processed_at (String)

Attributes:
- shard_id (String)
- total_records (Number)
- success_records (Number)
- failed_records (Number)
- partitions_count (Number)
- ttl (Number) - 30 days
```

**Indexes:**
- **ShardIndex (GSI):** Query by shard_id

**Billing:** On-demand (pay per request)

**Use Cases:**
- Audit trail
- Processing statistics
- Debugging and troubleshooting
- Data lineage tracking

### 8. Amazon CloudWatch

**Purpose:** Monitoring, logging, and alerting

**Log Groups:**
- `/aws/lambda/kinesis-processor`
- `/aws/lambda/s3-transformer`

**Metrics:**
- Lambda: Invocations, Errors, Duration, Throttles
- Kinesis: IncomingRecords, IteratorAge, Throughput
- DynamoDB: UserErrors, ConsumedCapacity

**Alarms:**
- High Lambda error rate (>5 errors in 2 minutes)
- Lambda throttling
- High Kinesis iterator age (>60 seconds)
- DynamoDB throttling

**X-Ray Tracing:**
- End-to-end request tracing
- Performance bottleneck identification
- Service map visualization

### 9. Amazon SQS (Dead Letter Queues)

**Purpose:** Capture failed Lambda invocations

**Configuration:**
- **Retention:** 14 days
- **Visibility Timeout:** 30 seconds

**DLQs:**
- `kinesis-processor-dlq`: Failed Kinesis processing
- `s3-transformer-dlq`: Failed S3 transformations

**Monitoring:**
- CloudWatch alarm on message count
- Manual inspection for debugging

## Data Flow

### Happy Path

1. **Ingestion (0-1s)**
   - Producer sends event to Kinesis
   - Kinesis acknowledges receipt
   - Event stored in shard

2. **Stream Processing (1-10s)**
   - Lambda polls Kinesis (every 1-5s)
   - Receives batch of up to 100 records
   - Validates and processes records
   - Writes to S3 raw bucket
   - Updates DynamoDB metadata

3. **S3 Event (10-15s)**
   - S3 triggers ObjectCreated event
   - Lambda receives S3 event notification

4. **Transformation (15-30s)**
   - Lambda reads raw data from S3
   - Transforms and enriches records
   - Writes to S3 processed bucket
   - Updates DynamoDB metadata

5. **Total Latency:** ~30 seconds end-to-end

### Error Handling

**Validation Errors:**
- Invalid records logged
- Not written to S3
- Counted in statistics

**Processing Errors:**
- Automatic retry (up to 3 times)
- Exponential backoff
- Failed records sent to DLQ

**Infrastructure Errors:**
- Lambda timeout: Partial batch processed
- S3 unavailable: Lambda retries automatically
- DynamoDB throttling: Exponential backoff

## Scalability

### Horizontal Scaling

**Kinesis:**
- Add shards: 2 → 4 → 8 → ...
- Each shard adds 1 MB/s write capacity

**Lambda:**
- Auto-scales based on Kinesis shard count
- One concurrent execution per shard
- Can process multiple batches in parallel

**S3:**
- Unlimited storage
- Automatic scaling
- 3,500 PUT/s per prefix

**DynamoDB:**
- On-demand scaling
- Automatic capacity adjustment

### Vertical Scaling

**Lambda Memory:**
- 512 MB → 1024 MB → 2048 MB
- More memory = more CPU
- Faster processing

**Kinesis Batch Size:**
- 100 → 500 → 1000 records
- Larger batches = fewer Lambda invocations
- Lower cost, higher latency

## Security

### Encryption

**At Rest:**
- Kinesis: KMS encryption
- S3: AES-256 server-side encryption
- DynamoDB: AWS-managed encryption

**In Transit:**
- HTTPS for all API calls
- TLS 1.2+ required

### Access Control

**IAM Roles:**
- Least privilege principle
- Separate roles for each Lambda
- No hardcoded credentials

**S3 Buckets:**
- Block all public access
- Bucket policies for service access
- Versioning for data protection

**Network:**
- VPC endpoints (optional)
- Private subnets for Lambda (optional)

### Compliance

- CloudTrail logging enabled
- All actions auditable
- Data retention policies
- Encryption at rest and in transit

## Cost Optimization

### Strategies

1. **Right-size resources:**
   - Reduce Lambda memory if not needed
   - Reduce Kinesis shards during low traffic

2. **Lifecycle policies:**
   - Move old data to Glacier
   - Delete after retention period

3. **On-demand billing:**
   - DynamoDB on-demand for variable traffic
   - Lambda pay-per-use

4. **Batch operations:**
   - Larger batch sizes reduce Lambda invocations
   - Batch writes to DynamoDB

5. **Log retention:**
   - Set CloudWatch log retention to 7 days
   - Export old logs to S3

### Cost Breakdown (Monthly)

**Development/Testing (Low Traffic):**
- Kinesis: $22 (2 shards)
- Lambda: $5 (1M invocations)
- S3: $5 (100 GB)
- DynamoDB: $2 (on-demand)
- CloudWatch: $2 (logs and metrics)
- **Total: ~$36/month**

**Production (Medium Traffic):**
- Kinesis: $88 (8 shards)
- Lambda: $20 (10M invocations)
- S3: $25 (1 TB)
- DynamoDB: $10 (on-demand)
- CloudWatch: $10 (logs and metrics)
- **Total: ~$153/month**

## Disaster Recovery

### Backup Strategy

**S3:**
- Versioning enabled
- Cross-region replication (optional)
- Lifecycle policies

**DynamoDB:**
- Point-in-time recovery enabled
- On-demand backups
- 30-day TTL for automatic cleanup

**Kinesis:**
- 24-hour retention
- Can replay from any point in retention window

### Recovery Procedures

**Data Loss:**
1. Check S3 versioning
2. Restore from backup
3. Replay Kinesis stream if within retention

**Service Outage:**
1. Kinesis buffers data (24 hours)
2. Lambda automatically retries
3. DLQ captures failures

**Region Failure:**
1. Deploy to secondary region
2. Update DNS/endpoints
3. Restore from S3 cross-region replica

## Monitoring and Observability

### Key Metrics

**Throughput:**
- Records per second
- Bytes per second
- Processing latency

**Reliability:**
- Error rate
- Success rate
- Retry count

**Performance:**
- Lambda duration
- Iterator age
- End-to-end latency

### Dashboards

**Operational Dashboard:**
- Real-time throughput
- Error rates
- Active alarms

**Performance Dashboard:**
- Latency percentiles (p50, p95, p99)
- Lambda duration
- Kinesis iterator age

**Cost Dashboard:**
- Daily spend by service
- Cost trends
- Optimization opportunities

## Future Enhancements

### Potential Improvements

1. **Real-time Analytics:**
   - Add Kinesis Data Analytics
   - Real-time aggregations
   - Streaming SQL queries

2. **Data Quality:**
   - Add AWS Glue Data Quality
   - Schema validation
   - Data profiling

3. **Machine Learning:**
   - Anomaly detection with SageMaker
   - Predictive analytics
   - Real-time scoring

4. **Advanced Monitoring:**
   - Custom CloudWatch dashboards
   - SNS notifications
   - PagerDuty integration

5. **Data Catalog:**
   - AWS Glue Crawler
   - Athena queries
   - QuickSight dashboards

6. **Multi-Region:**
   - Cross-region replication
   - Global table for DynamoDB
   - Route 53 failover
