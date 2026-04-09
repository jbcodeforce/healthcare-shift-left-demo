# Healthcare Shift-Left Demo - Complete Deployment Guide

**End-to-End Automated Deployment (Start to Finish)**

This guide will take you from zero to a fully working healthcare data streaming demo with analytics dashboard.

## 📋 Table of Contents

1. [Prerequisites](#prerequisites)
2. [Phase 1: Infrastructure Setup (Terraform)](#phase-1-infrastructure-setup-terraform)
3. [Phase 2: Flink Pipelines Deployment](#phase-2-flink-pipelines-deployment)
4. [Phase 3: Backend & Frontend (Docker)](#phase-3-backend--frontend-docker)
5. [Phase 4: Tableflow Setup (Optional)](#phase-4-tableflow-setup-optional)
6. [Phase 5: Verification & Testing](#phase-5-verification--testing)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Software

- **Docker** (20.10+) and **Docker Compose** (2.0+)
- **Terraform** (1.5+)
- **Python** (3.10+)
- **AWS CLI** (configured) - for Tableflow only
- **Git**

### Required Accounts

- **Confluent Cloud** account with admin access
- **AWS Account** (optional, for Tableflow S3 storage)

### Required Information

Before starting, collect these:
- ✅ Confluent Cloud API Key & Secret
- ✅ Existing Environment ID (or create new)
- ✅ Existing Kafka Cluster ID (or create new)
- ✅ AWS credentials (for Tableflow)

---

## Phase 1: Infrastructure Setup (Terraform)

**Duration**: 10-15 minutes  
**What it creates**: Confluent Cloud infrastructure

### Step 1.1: Clone Repository

```bash
# Clone the repo
git clone https://github.com/jbcodeforce/healthcare-shift-left-demo.git
cd healthcare-shift-left-demo
```

### Step 1.2: Configure Terraform Variables

```bash
cd IaC

# Create terraform.tfvars from example
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

**Minimal configuration** (using existing infrastructure):
```hcl
# Confluent Cloud API credentials
confluent_cloud_api_key    = "YOUR_CLOUD_API_KEY"
confluent_cloud_api_secret = "YOUR_CLOUD_API_SECRET"

# Use existing infrastructure
environment_id   = "env-xxxxx"   # Your environment ID
kafka_cluster_id = "lkc-xxxxx"   # Your Kafka cluster ID

# Optional: Use existing service account
service_account_id = "sa-xxxxx"  # If you have one

# Optional: Use existing API keys
kafka_api_key_id     = "YOUR_KAFKA_KEY"
kafka_api_key_secret = "YOUR_KAFKA_SECRET"

# Cloud configuration
cloud_provider = "AWS"
cloud_region   = "us-east-2"  # Must match your Kafka cluster region

# Flink configuration
flink_compute_pool_name    = "healthcare-demo-pool"
flink_compute_pool_max_cfu = 5

# DON'T deploy Flink statements yet (we'll do this in Phase 2)
deploy_flink_statements = false

# Tableflow (optional - can enable later)
enable_tableflow = false
```

### Step 1.3: Deploy Infrastructure

```bash
# Initialize Terraform (first time only)
terraform init

# Preview changes
terraform plan

# Deploy infrastructure
terraform apply
# Type 'yes' when prompted
```

**Expected output:**
```
Apply complete! Resources: X added, 0 changed, 0 destroyed.

Outputs:
env_id = "env-xxxxx"
kafka_cluster_id = "lkc-xxxxx"
flink_compute_pool_id = "lfcp-xxxxx"
...
```

### Step 1.4: Export Credentials to Backend

```bash
# Generate backend/.env configuration
terraform output -raw backend_env_snippet > ../backend/.env.terraform

# Merge with existing .env or create new one
cat ../backend/.env.terraform >> ../backend/.env

# Or manually copy the values shown in terraform output
terraform output backend_env_snippet
```

### Step 1.5: Verify Infrastructure

```bash
# Check outputs
terraform output env_id
terraform output kafka_cluster_id
terraform output flink_compute_pool_id

# All should show valid IDs
```

✅ **Phase 1 Complete!** Infrastructure is ready.

---

## Phase 2: Flink Pipelines Deployment

**Duration**: 10-15 minutes  
**What it deploys**: Flink SQL tables and processing pipelines

### Step 2.1: Prepare Environment

```bash
cd ../pipelines/flink_pipelines

# Install Python dependencies
pip install -r requirements.txt

# Source environment variables
source ../../backend/.env
```

### Step 2.2: Verify Configuration

```bash
# Check required environment variables
python3 -c "
import os
required = ['FLINK_REST_ENDPOINT', 'FLINK_API_KEY', 'FLINK_API_SECRET', 
            'FLINK_COMPUTE_POOL_ID', 'ENV_ID', 'PRINCIPAL_ID']
missing = [v for v in required if not os.getenv(v)]
print('✅ All variables set' if not missing else f'❌ Missing: {missing}')
"
```

### Step 2.3: Deploy Flink Pipelines

**Option A: Deploy All Pipelines (Recommended)**

```bash
# Deploy raw layer first, then rmd layer
python3 deploy_flink.py --all
```

**Option B: Deploy Layer by Layer**

```bash
# 1. Deploy raw layer (foundation tables)
python3 deploy_flink.py --layer raw

# Wait 2 minutes for tables to initialize...
sleep 120

# 2. Deploy rmd layer (transformations)
python3 deploy_flink.py --layer rmd
```

**Option C: Using dbt (Advanced)**

```bash
# If you have dbt installed
python3 dbt_flink_deploy.py --all
```

### Step 2.4: Verify Flink Deployments

```bash
# Check Confluent Cloud UI
# Go to: Environment → Flink → Statements

# You should see:
# ✅ Raw layer: 3 DDL + 3 DML statements (RUNNING)
# ✅ RMD layer: 7 DDL + 7 DML statements (RUNNING)
```

**Or verify via CLI:**
```bash
# List Flink statements
confluent flink statement list \
  --cloud aws \
  --region us-east-2 \
  --environment $ENV_ID \
  --compute-pool $FLINK_COMPUTE_POOL_ID
```

✅ **Phase 2 Complete!** Flink pipelines are processing data.

---

## Phase 3: Backend & Frontend (Docker)

**Duration**: 5 minutes  
**What it starts**: Backend API + Frontend UI + PostgreSQL

### Step 3.1: Verify Configuration

```bash
cd ../..  # Back to repo root

# Check backend/.env has all required variables
cat backend/.env | grep -E "KAFKA_BOOTSTRAP|SCHEMA_REGISTRY|FLINK_API"

# Should show values (not empty)
```

### Step 3.2: Start Docker Services

```bash
# Start all services
docker compose up -d backend frontend postgres

# Check status
docker compose ps

# Expected:
# ✅ backend   - Up (healthy)
# ✅ frontend  - Up
# ✅ postgres  - Up (healthy)
```

### Step 3.3: View Logs (Optional)

```bash
# Watch backend logs
docker compose logs -f backend

# Look for:
# ✅ "Application startup complete"
# ✅ "Uvicorn running on http://0.0.0.0:8000"
# ✅ "Seeded one prescription per patient to PostgreSQL"
```

### Step 3.4: Start Device Simulation

```bash
# Start simulating device telemetry
curl -X POST http://localhost:8000/simulation/start \
  -H "Content-Type: application/json" \
  -d '{"simulation_type": "all"}'

# Expected response:
# {"status": "started", "message": "Device simulation is running."}

# Verify simulation is running
curl http://localhost:8000/simulation/status
# {"running": true}
```

### Step 3.5: Access the Application

Open your browser:

1. **Frontend Application**: http://localhost:5173
   - Home page should load
   - Navigation menu visible

2. **Backend API Docs**: http://localhost:8000/docs
   - Swagger UI with all endpoints

3. **Analytics Dashboard**: http://localhost:5173/analytics
   - Shows sample data from local Parquet files

4. **Telemetry View**: http://localhost:5173/telemetry
   - Shows real-time streaming data from Kafka

✅ **Phase 3 Complete!** Application is running.

---

## Phase 4: Tableflow Setup (Optional)

**Duration**: 20-30 minutes  
**What it enables**: Real-time analytics data from S3

This phase is **optional** but recommended for production use. It enables writing Flink data to S3 for analytics.

### Step 4.1: Get Confluent External ID

**Option A: From Confluent UI**
1. Go to Confluent Cloud Console
2. Navigate to: Environment → Settings → Tableflow
3. Copy the External ID

**Option B: Contact Confluent Support**
- Request the External ID for your organization

### Step 4.2: Enable Tableflow in Terraform

```bash
cd IaC

# Edit terraform.tfvars
nano terraform.tfvars

# Add these lines:
enable_tableflow = true
confluent_external_id = "your-external-id-from-step-4.1"
```

### Step 4.3: Deploy S3 Infrastructure

```bash
# AWS credentials should be configured
aws sts get-caller-identity

# Deploy Tableflow infrastructure
terraform apply
# Type 'yes' when prompted
```

**This creates:**
- S3 bucket: `health-healthcare-analytics-xxxxxxxx`
- IAM role: `health-tableflow-role`
- IAM policy with S3 permissions

### Step 4.4: Get S3 Configuration

```bash
# Get bucket name
export BUCKET=$(terraform output -raw s3_analytics_bucket)
echo "S3 Bucket: $BUCKET"

# Get IAM Role ARN
export ROLE_ARN=$(terraform output -raw tableflow_iam_role_arn)
echo "IAM Role: $ROLE_ARN"

# Get S3 paths
terraform output analytics_s3_paths
```

### Step 4.5: Configure Tableflow Connections (Manual)

For each of the 3 fact tables, configure Tableflow via Confluent UI:

#### Connection 1: Anomaly Detection

1. **Go to**: Confluent Cloud → Environment → Tableflow → "Add Connection"
2. **Connection Name**: `hc_fct_dev_anomaly_s3`
3. **Type**: Amazon S3
4. **Authentication**: IAM Role
5. **IAM Role ARN**: Paste `$ROLE_ARN` from above
6. **External ID**: Your Confluent External ID
7. **Test Connection** → Should succeed ✅

8. **Create Sink**:
   - Source: `env-xxxxx.lkc-xxxxx.hc_fct_dev_anomaly`
   - Destination: `s3://$BUCKET/anomalies/`
   - Format: **Parquet**
   - Compression: **Snappy**
   - Partitioning: **Enabled**, Column: **date**
   - Click "Create"

#### Connection 2: Prescription Changes

Repeat for drift events:
- **Connection Name**: `hc_fct_drift_evts_s3`
- **Source**: `hc_fct_drift_evts`
- **Destination**: `s3://$BUCKET/prescription_changes/`
- Same format settings

#### Connection 3: Telemetry

Repeat for telemetry:
- **Connection Name**: `hc_fct_telemetries_s3`
- **Source**: `hc_fct_telemetries`
- **Destination**: `s3://$BUCKET/telemetries/`
- Same format settings

**See detailed steps**: `IaC/MANUAL_TABLEFLOW_STEPS.md`

### Step 4.6: Verify Data Flow to S3

```bash
# Wait 5-10 minutes for data to flow
sleep 600

# Check S3 for data
aws s3 ls s3://$BUCKET/anomalies/ --recursive
aws s3 ls s3://$BUCKET/prescription_changes/ --recursive
aws s3 ls s3://$BUCKET/telemetries/ --recursive

# Should see files like:
# anomalies/date=2026-04-08/part-00000.parquet
```

### Step 4.7: Update Backend to Use S3

```bash
cd ../backend

# Add S3 configuration to .env
cat >> .env << EOF

# Analytics S3 Configuration (Tableflow)
ANALYTICS_S3_BUCKET=${BUCKET}
ANALYTICS_S3_PREFIX=
AWS_REGION=us-east-2
EOF

# Comment out local path
sed -i.bak 's/^ANALYTICS_LOCAL_PATH=/#ANALYTICS_LOCAL_PATH=/' .env

# Restart backend
cd ..
docker compose restart backend
```

### Step 4.8: Verify S3 Analytics

```bash
# Wait for backend to restart
sleep 10

# Test S3 analytics
curl http://localhost:8000/analytics/dashboard | jq '.available'
# Should return: true

# Check data source
curl http://localhost:8000/analytics/anomalies-per-device | jq
# Should show data from S3
```

✅ **Phase 4 Complete!** Real-time analytics from S3 enabled.

---

## Phase 5: Verification & Testing

**Duration**: 10 minutes  
**Verify**: Everything is working end-to-end

### Step 5.1: Verify Data Flow

```bash
# 1. Check simulation is running
curl http://localhost:8000/simulation/status
# {"running": true}

# 2. Check telemetry is being sent to Kafka
curl http://localhost:8000/telemetry/metrics | jq '. | length'
# Should show > 0 records

# 3. Check prescriptions in PostgreSQL
curl http://localhost:8000/prescriptions | jq '. | length'
# Should show 5 prescriptions

# 4. Check analytics data
curl http://localhost:8000/analytics/dashboard | jq '.available'
# true
```

### Step 5.2: Test UI Features

**Open Browser**: http://localhost:5173

1. **Home Page** ✅
   - Loads without errors
   - Navigation menu works

2. **Patients Page** ✅
   - Shows 5 patients
   - Can view patient details

3. **Devices Page** ✅
   - Shows 5 devices
   - Can view device details

4. **Prescriptions Page** ✅
   - Shows 5 prescriptions
   - Can create/edit/delete prescriptions

5. **Telemetry Page** ✅
   - Shows real-time streaming data
   - Charts update automatically
   - SSE connection working

6. **Analytics Dashboard** ✅
   - Shows 3 charts
   - Anomalies per device (bar chart)
   - Configuration changes over time (line chart)
   - New devices over time (line chart)

### Step 5.3: Test Anomaly Scenarios

```bash
# Trigger anomaly scenarios on devices
curl -X POST "http://localhost:8000/device/DEV-P001/simulator/flow_level_down"
curl -X POST "http://localhost:8000/device/DEV-P003/simulator/pressure_oscillate"
curl -X POST "http://localhost:8000/device/DEV-P005/simulator/flow_rate_down"

# Wait a moment
sleep 5

# Check telemetry view in browser - should see anomalies
```

### Step 5.4: Verify Flink Processing

**In Confluent Cloud UI**:
1. Go to: Environment → Flink → Statements
2. Check all statements show **RUNNING**
3. Click on a statement → View metrics
4. Should see records processed

### Step 5.5: Verify Tableflow (If Enabled)

**In Confluent Cloud UI**:
1. Go to: Environment → Tableflow → Sinks
2. All 3 sinks should show **RUNNING**
3. Check metrics show data written to S3

### Step 5.6: Create Test Data

```bash
# Add a new prescription
curl -X POST http://localhost:8000/prescriptions \
  -H "Content-Type: application/json" \
  -d '{
    "patient_id": "P001",
    "device_id": "DEV-P001",
    "medication_or_therapy": "Updated CPAP Protocol",
    "parameters": [
      {"parameter_name": "Pressure", "parameter_value": 12.0, "parameter_type": "float", "parameter_tolerance": 1.5},
      {"parameter_name": "FlowRate", "parameter_value": 3.0, "parameter_type": "float", "parameter_tolerance": 0.5}
    ]
  }'

# Should return the created prescription
```

✅ **Phase 5 Complete!** Everything is verified and working.

---

## 🎯 Deployment Summary

After completing all phases, you have:

### Infrastructure (Confluent Cloud)
- ✅ Environment configured
- ✅ Kafka cluster running
- ✅ Schema Registry configured
- ✅ Flink compute pool active
- ✅ Service account with API keys

### Data Processing
- ✅ 3 Raw tables (Kafka → Flink)
- ✅ 7 RMD tables (Flink transformations)
- ✅ Anomaly detection running (ML-based)
- ✅ Drift detection active
- ✅ Telemetry aggregation

### Application
- ✅ Backend API (FastAPI)
- ✅ Frontend UI (Vue.js)
- ✅ PostgreSQL database
- ✅ Device simulation running
- ✅ Real-time telemetry streaming

### Analytics (Optional)
- ✅ S3 bucket for Parquet data
- ✅ Tableflow writing to S3
- ✅ DuckDB analytics engine
- ✅ Interactive dashboards

---

## 🛠️ Troubleshooting

### Issue: Terraform Apply Fails

**Error**: Authentication failed

**Fix**:
```bash
# Verify API credentials
echo $TF_VAR_confluent_cloud_api_key
# Should not be empty

# Check credentials are valid
curl -u "$TF_VAR_confluent_cloud_api_key:$TF_VAR_confluent_cloud_api_secret" \
  https://api.confluent.cloud/org/v2/organizations
```

### Issue: Flink Deployment Fails

**Error**: "Missing required environment variables"

**Fix**:
```bash
# Source backend/.env
source ../../backend/.env

# Verify variables
env | grep -E "FLINK|ENV_ID|PRINCIPAL"
```

### Issue: Docker Services Won't Start

**Error**: "Port already allocated"

**Fix**:
```bash
# Check what's using the port
lsof -i :8000
lsof -i :5173
lsof -i :5432

# Stop conflicting services or change ports in docker-compose.yml
```

### Issue: No Data in Analytics

**Error**: Analytics shows "not available"

**Fix**:
```bash
# Check backend logs
docker compose logs backend | grep analytics

# Verify configuration
docker exec backend env | grep ANALYTICS

# For local mode, ensure path exists
ls -la analytics/sample-data/parquet/

# For S3 mode, verify AWS credentials
aws s3 ls s3://your-bucket/
```

### Issue: Simulation Not Sending Data

**Fix**:
```bash
# Check simulation status
curl http://localhost:8000/simulation/status

# Restart simulation
curl -X POST http://localhost:8000/simulation/stop
curl -X POST http://localhost:8000/simulation/start

# Check backend logs for Kafka errors
docker compose logs backend | grep -i kafka
```

---

## 📚 Additional Resources

- **Full Documentation**: https://jbcodeforce.github.io/healthcare-shift-left-demo
- **Terraform Guide**: `IaC/README.md`
- **Tableflow Setup**: `IaC/TABLEFLOW_SETUP_GUIDE.md`
- **dbt Deployment**: `pipelines/DBT_DEPLOYMENT_GUIDE.md`
- **API Documentation**: http://localhost:8000/docs (when running)

---

## 🔄 Updating the Deployment

### Update Flink Pipelines

```bash
cd pipelines/flink_pipelines

# Redeploy all
python3 deploy_flink.py --all

# Or redeploy specific layer
python3 deploy_flink.py --layer rmd
```

### Update Backend/Frontend

```bash
# Pull latest code
git pull

# Rebuild and restart
docker compose down
docker compose up -d --build backend frontend
```

### Update Terraform Infrastructure

```bash
cd IaC

# Pull latest changes
git pull

# Apply updates
terraform plan
terraform apply
```

---

## 🧹 Cleanup

### Stop Application

```bash
# Stop Docker services
docker compose down

# Remove volumes (deletes database)
docker compose down -v
```

### Destroy Infrastructure

```bash
cd IaC

# Destroy Tableflow resources (optional)
terraform destroy -target=aws_s3_bucket.analytics

# Destroy all infrastructure
terraform destroy
# Type 'yes' when prompted
```

### Stop Flink Statements

```bash
# Via Confluent UI
# Go to: Flink → Statements → Select all → Stop

# Or via CLI
confluent flink statement list --compute-pool $FLINK_COMPUTE_POOL_ID \
  | grep statement-id | while read id; do
    confluent flink statement delete $id
  done
```

---

**Deployment Complete!** 🎉

You now have a fully functional healthcare data streaming platform with real-time analytics.

**Estimated Total Time**: 
- Manual deployment: 45-60 minutes
- Automated (with scripts): 20-30 minutes

**Next Steps**:
- Explore the UI features
- Create custom Flink transformations
- Add more devices to the simulation
- Integrate with your own data sources
