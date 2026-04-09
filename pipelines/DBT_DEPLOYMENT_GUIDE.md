# dbt Deployment for Flink Pipelines - Issue #3 Implementation

## ✅ What Was Implemented

This implementation enables deploying Flink SQL pipelines to Confluent Cloud using **dbt** as requested in Issue #3.

### Components

1. **`pipelines/inventory.json`** — DDL/DML paths per table.
2. **`generate_flink_models.py`** — builds **`models/flink/**`** ephemeral models with **`meta.deploy_sequence`**.
3. **`dbt compile`** → **`target/manifest.json`** **`compiled_code`** (Flink SQL).
4. **`dbt_flink_deploy.py`** — compile + **`deploy_from_manifest()`** (REST).
5. **`deploy_flink.py`** — REST from inventory paths only.
6. **Macros** — `deploy_flink_pipelines` run-operation (shell hints).

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

### Regenerate dbt models (when inventory changes)

```bash
cd pipelines/flink_pipelines
python3 generate_flink_models.py
```

Commit updated files under `models/flink/`.

### Deploy Flink Pipelines

#### Option A (full dbt pipeline — recommended)

Runs **`dbt compile`**, then deploys **`compiled_code`** from **`target/manifest.json`** in **`deploy_sequence`** order:

```bash
cd pipelines/flink_pipelines
python3 dbt_flink_deploy.py --all
python3 dbt_flink_deploy.py --layer raw
python3 dbt_flink_deploy.py --table hc_raw_patients
```

Reuse the last compile without re-running dbt:

```bash
python3 dbt_flink_deploy.py --skip-dbt-compile --all
```

Same REST behavior as inventory, but skip dbt entirely:

```bash
python3 dbt_flink_deploy.py --legacy-inventory --all
```

Print shell reminders from repo root:

```bash
dbt run-operation deploy_flink_pipelines --project-dir pipelines/flink_pipelines --profiles-dir pipelines/flink_pipelines
```

#### Option B: REST deploy only (`deploy_flink.py`)

```bash
cd pipelines/flink_pipelines
python3 deploy_flink.py --all
python3 deploy_flink.py --layer rmd
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
│   ├── profiles.yml           # Postgres profile (compile/docs)
│   ├── generate_flink_models.py
│   ├── flink_deployer.py
│   ├── dbt_flink_deploy.py    # dbt compile + manifest deploy
│   ├── deploy_flink.py        # inventory-only REST CLI
│   ├── README.md
│   ├── models/
│   │   └── flink/
│   │       ├── raw/           # generated flink__*__ddl.sql / __dml.sql
│   │       ├── rmd/
│   │       └── schema.yml
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

### Deployment order

**`dbt_flink_deploy.py` (default):** statements run in ascending **`meta.deploy_sequence`** (set by `generate_flink_models.py`). That follows **`inventory.json` key order**: for each **`product_name`** `raw` then `rmd`, each table gets **DDL then DML**.

**`deploy_flink.py` / `--legacy-inventory`:** same ordering, reading SQL files from **`inventory.json`** paths directly.

## 🔧 How It Works

1. **Inventory** defines DDL/DML paths.
2. **Generator** copies SQL into dbt models under **`models/flink/`** (regenerate when inventory changes).
3. **`dbt compile`** fills **`compiled_code`** on each model in **`manifest.json`**.
4. **Deploy** POSTs each compiled statement to Confluent Flink REST (plus **`.properties`** for DML when present).
5. **Credentials** from **`backend/.env`**.

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
- ✅ `dbt compile` + manifest-driven deploy (via `dbt_flink_deploy.py`)
- ✅ Data engineer can deploy pipelines easily

## 🎓 Example Workflow

```bash
# 1. Edit Flink SQL under pipelines/raw or pipelines/rmd
vim pipelines/rmd/hc_fct_drift_evts/sql-scripts/dml.hc_fct_drift_evts.sql

# 2. If inventory.json changed, regenerate dbt models
cd pipelines/flink_pipelines
python3 generate_flink_models.py

# 3. Compile + deploy
python3 dbt_flink_deploy.py --table hc_fct_drift_evts

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
echo $ORG_ID
```

`ORG_ID` must be set to your Confluent organization UUID (used in the Flink REST URL). Empty `ORG_ID` fails fast in `flink_deployer.py`.

### Deployment Fails

```bash
# Check Flink statement status
confluent flink statement list --compute-pool $FLINK_COMPUTE_POOL_ID

# View specific statement
confluent flink statement describe <statement-name>
```

### dbt Warnings

If you add `schema.yml` patches, ensure `name:` matches a model under `models/flink/`.

## 🎉 Summary

```bash
cd pipelines/flink_pipelines
python3 generate_flink_models.py    # when inventory.json changes
python3 dbt_flink_deploy.py --all  # compile + deploy from manifest
```

Or: `python3 deploy_flink.py --all` / `python3 dbt_flink_deploy.py --legacy-inventory --all` for inventory-only REST.
