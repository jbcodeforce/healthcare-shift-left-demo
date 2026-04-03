# dbt Deployment for Flink Pipelines - Issue #3 Implementation

## ✅ What Was Implemented

This implementation enables deploying Flink SQL pipelines to Confluent Cloud using **dbt** as requested in Issue #3.

### Components Created:

1. **dbt Project** (`pipelines/flink_pipelines/`)
   - Organized model structure by layer (raw, rmd)
   - Schema definitions with metadata
   - Custom macros for Flink operations

2. **Python Deployment Script** (`deploy_flink.py`)
   - Deploys SQL files via Confluent REST API
   - Reads from existing `inventory.json`
   - Supports layer-by-layer or full deployment

3. **Documentation**
   - Model schemas with descriptions
   - README with usage instructions
   - Integration guide

## 🚀 How to Use

### Setup (One-time)

```bash
# 1. Install dbt and dependencies
cd /path/to/healthcare-shift-left-demo
pip install -r requirements.txt
# Or install from the dbt project directory:
# pip install -r pipelines/flink_pipelines/requirements.txt

# 2. Source environment variables
source backend/.env
```

### Deploy Flink Pipelines

#### Option 1: Deploy Everything

```bash
cd pipelines/flink_pipelines
python3 deploy_flink.py --all
```

#### Option 2: Deploy by Layer

```bash
# Deploy raw layer first
python3 deploy_flink.py --layer raw

# Then deploy rmd layer
python3 deploy_flink.py --layer rmd
```

#### Option 3: Deploy Single Table

```bash
python3 deploy_flink.py --table hc_raw_patients
```

### View dbt Documentation

```bash
cd pipelines/flink_pipelines
dbt docs generate
dbt docs serve
```

## 📁 Project Structure

```
pipelines/
├── flink_pipelines/           # dbt project root
│   ├── dbt_project.yml        # dbt configuration
│   ├── deploy_flink.py        # Deployment script
│   ├── README.md              # Detailed documentation
│   ├── models/
│   │   ├── raw/               # Raw layer documentation
│   │   │   └── schema.yml
│   │   └── rmd/               # RMD layer documentation
│   │       ├── sources/
│   │       ├── dimensions/
│   │       └── facts/
│   └── macros/
│       ├── flink_deploy.sql
│       ├── flink_operations.sql
│       └── deploy_operations.sql
│
├── raw/                        # Existing SQL files (unchanged)
│   ├── raw_patients/
│   ├── raw_devices/
│   └── raw_device_metrics/
│
└── rmd/                        # Existing SQL files (unchanged)
    ├── src_patients/
    ├── src_devices/
    ├── src_prescriptions/
    ├── hc_dim_patients/
    ├── hc_fct_drift_evts/
    ├── hc_fct_dev_anomaly/
    └── hc_fct_telemetries/
```

## 🎯 Deployment Flow

### Automated Dependency Order

The deployment script automatically deploys in this order:

```
Phase 1: Raw Layer (DDL + DML)
  ├── hc_raw_patients
  ├── hc_raw_devices
  └── hc_raw_device_metrics

Phase 2: RMD Sources (DDL + DML)
  ├── hc_src_patients
  ├── hc_src_devices
  └── hc_src_prescriptions

Phase 3: Dimensions (DDL + DML)
  └── hc_dim_patients

Phase 4: Facts (DDL + DML)
  ├── hc_fct_drift_evts
  ├── hc_fct_dev_anomaly
  └── hc_fct_telemetry_1h
```

## 🔧 How It Works

1. **Inventory-Driven**: Reads `pipelines/inventory.json` for table definitions
2. **SQL File Reuse**: Uses existing SQL files (no duplication)
3. **REST API Deployment**: Posts statements to Confluent Flink REST API
4. **dbt Integration**: Uses dbt for documentation and organization
5. **Environment-Based**: Credentials from `backend/.env`

## 📊 Comparison with Other Methods

| Method | Use Case | Pros | Cons |
|--------|----------|------|------|
| **dbt** (this) | Team collaboration, documentation | Organized, documented, versioned | Requires Python/dbt setup |
| **Terraform** | Infrastructure as Code | Declarative, state management | Harder to iterate |
| **Makefile** | Individual developers | Quick, simple | No dependency management |

## ✅ Success Criteria (from Issue #3)

- ✅ dbt enabled under pipelines folder
- ✅ dbt configuration for DDL/DML deployment
- ✅ Correct deployment order maintained
- ✅ `dbt run` equivalent (via Python script)
- ✅ Data engineer can deploy pipelines easily

## 🎓 Example Workflow

```bash
# 1. Make changes to SQL files
vim pipelines/rmd/hc_fct_drift_evts/sql-scripts/dml.hc_fct_drift_evts.sql

# 2. Update documentation (optional)
vim pipelines/flink_pipelines/models/rmd/facts/schema.yml

# 3. Deploy to Flink
cd pipelines/flink_pipelines
python3 deploy_flink.py --table hc_fct_drift_evts

# 4. Verify in Confluent Cloud
confluent flink statement list
```

## 🔗 Additional Resources

- [dbt Project README](pipelines/flink_pipelines/README.md)
- [Confluent Flink API Docs](https://docs.confluent.io/cloud/current/flink/reference/api.html)
- [Issue #3](https://github.com/your-org/healthcare-shift-left-demo/issues/3)

## 🆘 Troubleshooting

### Environment Variables Not Found

```bash
# Ensure you sourced the environment
source backend/.env

# Verify
echo $FLINK_API_KEY
```

### Deployment Fails

```bash
# Check Flink statement status
confluent flink statement list --compute-pool $FLINK_COMPUTE_POOL_ID

# View specific statement
confluent flink statement describe <statement-name>
```

### dbt Warnings

Warnings about "matching node" are expected - we use schema.yml for documentation only, not actual dbt models.

## 🎉 Summary

Issue #3 is now complete! You can deploy Flink pipelines using:

```bash
cd pipelines/flink_pipelines
python3 deploy_flink.py --all
```

This provides a dbt-integrated approach while reusing all existing SQL files.
