# Tableflow Setup Guide

This guide explains how to enable Confluent Tableflow to write Flink analytics data to S3 as Parquet files.

## 📊 Overview

Tableflow connects Flink tables to object storage (S3) automatically, writing data as Parquet or Iceberg tables. This enables:

- **Real-time analytics** - Query fresh data from S3 with DuckDB
- **Historical analysis** - Access historical data without querying Kafka
- **Cost optimization** - Store analytics data in cheaper S3 instead of Kafka retention
- **Data lake integration** - Make Flink output available to other analytics tools

## 🏗️ Architecture

```
Flink Tables (in Confluent Cloud)
    ├── hc_fct_dev_anomaly      ──► S3: /anomalies/
    ├── hc_fct_drift_evts       ──► S3: /prescription_changes/
    └── hc_fct_telemetries      ──► S3: /telemetries/
                                          │
                                          ▼
                                    DuckDB Analytics
                                    (Backend reads Parquet)
```

## 📋 Prerequisites

1. **Flink tables deployed and running** (Issue #3 - dbt deployment)
2. **AWS account** with permissions to create:
   - S3 buckets
   - IAM roles and policies
3. **Confluent Cloud environment** with Tableflow enabled
4. **Terraform** installed locally

## 🚀 Step-by-Step Setup

### Step 1: Get Confluent External ID

The External ID is required for secure cross-account IAM role assumption.

**Option A: From Confluent UI**
1. Go to Confluent Cloud Console
2. Navigate to your Environment → Settings → Tableflow
3. Copy the External ID shown

**Option B: Contact Confluent Support**
- Request the External ID for your organization
- It's unique to your Confluent Cloud organization

### Step 2: Configure Terraform Variables

Edit `IaC/terraform.tfvars` and add:

```hcl
# Enable Tableflow
enable_tableflow = true

# External ID from Step 1
confluent_external_id = "your-external-id-from-confluent"

# Confluent AWS Account ID (default is correct for most users)
confluent_aws_account_id = "761327592718"
```

### Step 3: Configure AWS Credentials

Ensure your AWS credentials are configured:

```bash
# Option A: AWS CLI profile
export AWS_PROFILE=your-profile

# Option B: Environment variables
export AWS_ACCESS_KEY_ID=your-access-key
export AWS_SECRET_ACCESS_KEY=your-secret-key
export AWS_REGION=us-east-2  # Must match your Kafka cluster region
```

### Step 4: Deploy Terraform

```bash
cd IaC

# Initialize AWS provider (first time only)
terraform init

# Review changes
terraform plan

# Deploy S3 bucket, IAM role, and Tableflow connections
terraform apply
```

This will create:
- ✅ S3 bucket: `health-healthcare-analytics-<random>`
- ✅ IAM role: `health-tableflow-role`
- ✅ IAM policy: `health-tableflow-s3-policy`
- ✅ 3 Tableflow connections (one per fact table)
- ✅ 3 Tableflow sinks (writing to S3)

### Step 5: Get S3 Bucket Information

```bash
# Get the S3 bucket name
terraform output s3_analytics_bucket

# Get all S3 paths
terraform output analytics_s3_paths
```

Example output:
```json
{
  "anomalies": "s3://health-healthcare-analytics-a1b2c3d4/anomalies",
  "prescription_changes": "s3://health-healthcare-analytics-a1b2c3d4/prescription_changes",
  "telemetries": "s3://health-healthcare-analytics-a1b2c3d4/telemetries"
}
```

### Step 6: Update Backend Configuration

Update `backend/.env` with the S3 configuration:

```bash
# Get the bucket name from Terraform
BUCKET_NAME=$(cd IaC && terraform output -raw s3_analytics_bucket)

# Update backend/.env
cat >> backend/.env << EOF

# Analytics S3 Configuration (from Tableflow)
ANALYTICS_S3_BUCKET=${BUCKET_NAME}
ANALYTICS_S3_PREFIX=
AWS_REGION=us-east-2
EOF
```

**Important**: Remove or comment out the local path:
```bash
# ANALYTICS_LOCAL_PATH=/analytics/sample-data/parquet  # Disabled - using S3 now
```

### Step 7: Restart Backend to Use S3 Data

```bash
# If using Docker
docker compose restart backend

# If running locally
cd backend
uv run uvicorn backend.main:app --reload
```

### Step 8: Verify Data Flow

**Check Tableflow Status:**
```bash
# Via Confluent UI
# Environment → Tableflow → Connections
# You should see 3 connections in "Running" state

# Via CLI (if available)
confluent tableflow sink list --environment-id env-xxxxx
```

**Verify S3 Data:**
```bash
# List files in S3
aws s3 ls s3://health-healthcare-analytics-xxxxx/anomalies/ --recursive

# Expected structure (Hive partitioning):
# anomalies/date=2026-04-08/part-00000.parquet
# prescription_changes/date=2026-04-08/part-00000.parquet
# telemetries/date=2026-04-08/part-00000.parquet
```

**Test Analytics Dashboard:**
```bash
# Check if backend can read from S3
curl http://localhost:8000/analytics/dashboard | jq '.available'
# Should return: true

# View anomaly data
curl http://localhost:8000/analytics/anomalies-per-device | jq
```

## 🔧 Configuration Details

### S3 Bucket Features

- **Encryption**: AES256 server-side encryption enabled
- **Versioning**: Enabled for data protection
- **Lifecycle**: Old data expires after 90 days
- **Partitioning**: Hive-style by date (`/date=YYYY-MM-DD/`)

### IAM Role Trust Policy

The IAM role `health-tableflow-role` trusts Confluent's AWS account with your External ID:

```json
{
  "Principal": {
    "AWS": "arn:aws:iam::761327592718:root"
  },
  "Condition": {
    "StringEquals": {
      "sts:ExternalId": "your-external-id"
    }
  }
}
```

### Tableflow Sink Configuration

Each sink writes:
- **Format**: Parquet (columnar, compressed)
- **Partitioning**: By `date` column
- **Catalog**: Confluent environment ID
- **Database**: Kafka cluster ID
- **Table**: Flink table name

## 🎯 Success Criteria

Verify Issue #5 is complete:

- ✅ **Tableflow enabled** on all 3 fact tables
- ✅ **S3 bucket created** via Terraform
- ✅ **IAM role and policy** configured
- ✅ **Data flowing to S3** (check Confluent UI or S3)
- ✅ **DuckDB can query S3** (analytics dashboard shows data)

```bash
# Final verification
curl http://localhost:8000/analytics/dashboard | jq '.available, .anomalies_per_device | length, .config_changes_over_time | length'

# Expected:
# true
# > 0
# > 0
```

## 🛠️ Troubleshooting

### Issue: External ID not found

**Error**: `InvalidPermission.NotFound` or `Access Denied` when creating IAM role

**Solution**: Verify the External ID with Confluent support or in the Confluent UI

### Issue: Tableflow connection fails

**Error**: Tableflow connection status shows "Failed"

**Check**:
1. IAM role ARN is correct in Terraform
2. External ID matches your Confluent organization
3. IAM policy allows S3 bucket access
4. AWS credentials are valid

### Issue: No data in S3

**Check**:
1. Flink tables are running and processing data
2. Tableflow sink status is "Running" (not "Paused")
3. Data is flowing through Flink pipelines

```bash
# Check Flink statement status
confluent flink statement list --environment-id env-xxxxx --compute-pool-id lfcp-xxxxx
```

### Issue: Backend can't read S3 data

**Error**: Analytics dashboard shows "not available" or empty data

**Check**:
1. `ANALYTICS_S3_BUCKET` is set in `backend/.env`
2. AWS credentials have S3 read access
3. Bucket name is correct (no typos)
4. Data exists in S3 (use `aws s3 ls`)

**Debug**:
```bash
# Check backend logs
docker compose logs backend | grep -i analytics

# Test DuckDB S3 access directly
cd backend
uv run python -c "
from backend.analytics import get_anomalies_per_device
print(get_anomalies_per_device())
"
```

## 📊 Cost Optimization

### S3 Storage Costs

Approximate costs (us-east-2):
- Standard S3: ~$0.023/GB/month
- Lifecycle to Glacier after 30 days: ~$0.004/GB/month

### Tableflow Pricing

- Charged per GB written to S3
- See Confluent Cloud pricing page for current rates
- Much cheaper than long Kafka retention

### Optimization Tips

1. **Partition pruning**: Query specific dates to reduce scanned data
2. **Compaction**: Enable in Tableflow to reduce file count
3. **Lifecycle policies**: Move old data to Glacier storage class
4. **Retention**: Set reasonable expiration (90 days in this setup)

## 🔄 Maintenance

### Updating Tableflow Configuration

To modify sink configuration (e.g., change partitioning):

```bash
cd IaC

# Edit tableflow.tf
# - Change partition_columns
# - Update storage_uri
# - Modify format settings

# Apply changes
terraform apply
```

### Disabling Tableflow

To stop data flow and save costs:

```bash
cd IaC

# Set enable_tableflow = false in terraform.tfvars
# Then apply
terraform apply

# This will:
# - Stop all Tableflow sinks
# - Delete connections
# - Keep S3 data intact (not deleted)
```

### Cleaning Up

To remove all Tableflow resources:

```bash
cd IaC

# Destroy only Tableflow resources
terraform destroy -target=aws_s3_bucket.analytics \
  -target=aws_iam_role.tableflow \
  -target=confluent_tableflow_connection.dev_anomaly \
  -target=confluent_tableflow_connection.drift_evts \
  -target=confluent_tableflow_connection.telemetries

# Or destroy everything
terraform destroy
```

## 📚 Additional Resources

- [Confluent Tableflow Documentation](https://docs.confluent.io/cloud/current/tableflow/)
- [DuckDB S3 Integration](https://duckdb.org/docs/guides/import/s3_import.html)
- [Apache Parquet Format](https://parquet.apache.org/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

## ✅ Next Steps

After Tableflow is running:

1. **Monitor data flow**: Check Confluent UI for sink status
2. **Query fresh data**: Use analytics dashboard to view real-time metrics
3. **Add more tables**: Extend to other Flink tables if needed
4. **Optimize queries**: Add indexes or partition pruning
5. **Set up alerts**: Monitor for sink failures or delays

---

**Issue #5 Complete!** 🎉

You now have real-time analytics data flowing from Flink → S3 → DuckDB → Analytics Dashboard.
