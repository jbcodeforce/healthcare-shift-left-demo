# Healthcare Shift-Left Demo - Deployment Documentation Index

## 🎯 Choose Your Path

| I want to... | Use this guide | Time |
|--------------|----------------|------|
| **Get started quickly** | [QUICK_START.md](QUICK_START.md) | 30 min |
| **Understand everything** | [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) | 45-60 min |
| **Automate deployment** | [deploy.sh](deploy.sh) | 30 min |
| **Set up Tableflow (S3)** | [IaC/README.md — Tableflow and S3](IaC/README.md#tableflow-and-s3) | 20 min |
| **Deploy with dbt** | [pipelines/DBT_DEPLOYMENT_GUIDE.md](pipelines/DBT_DEPLOYMENT_GUIDE.md) | 15 min |

---

## 📚 Documentation Structure

### Getting Started

1. **[QUICK_START.md](QUICK_START.md)** - TL;DR version
   - Fast track deployment in 30 minutes
   - Essential commands only
   - Quick diagnostics

2. **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Complete guide
   - Step-by-step from zero to running
   - All phases explained
   - Comprehensive troubleshooting

3. **[deploy.sh](deploy.sh)** - Automated script
   - One-command deployment
   - Interactive or fully automated
   - Built-in verification

### Infrastructure

4. **[IaC/README.md](IaC/README.md)** - Terraform infrastructure
   - Confluent Cloud resources
   - Flink compute pools
   - API key management

5. **[IaC/README.md — Tableflow and S3](IaC/README.md#tableflow-and-s3)** - S3 analytics
   - Terraform: S3 bucket and IAM; Confluent UI: connections and sinks
   - Backend `ANALYTICS_S3_*` and verification
   - [docs/TABLEFLOW_SETUP_GUIDE.md](TABLEFLOW_SETUP_GUIDE.md) (short intro; links to the same section on GitHub for the doc site)

### Data Pipelines

6. **[pipelines/DBT_DEPLOYMENT_GUIDE.md](pipelines/DBT_DEPLOYMENT_GUIDE.md)** - Flink with dbt
   - dbt integration
   - Model generation
   - Deployment options

7. **[pipelines/README.md](pipelines/README.md)** - Pipeline overview
   - Data flow architecture
   - SQL pipeline definitions

### Application

8. **[backend/README.md](backend/README.md)** - Backend API
   - FastAPI setup
   - Kafka integration
   - Analytics endpoints

9. **[frontend/README.md](frontend/README.md)** - Frontend UI
    - Vue.js application
    - Chart.js dashboards
    - Real-time telemetry

---

## 🚀 Deployment Options

### Option 1: Automated Script (Recommended)

**Best for**: Quick deployment, testing, demos

```bash
# Full automated deployment
./deploy.sh --auto-approve

# Interactive deployment with prompts
./deploy.sh

# Skip certain phases
./deploy.sh --skip-terraform
```

**See**: `./deploy.sh --help`

### Option 2: Manual Step-by-Step

**Best for**: Learning, customization, production

```bash
# Follow the complete guide
cat DEPLOYMENT_GUIDE.md
```

**Phases**:
1. Infrastructure (Terraform) - 10 min
2. Flink Pipelines - 10 min
3. Docker Services - 5 min
4. Tableflow (optional) - 20 min
5. Verification - 5 min

### Option 3: Quick Start Commands

**Best for**: Experienced users who know what they're doing

```bash
# Infrastructure
cd IaC && terraform init && terraform apply

# Flink
cd ../pipelines/flink_pipelines
source ../../backend/.env
python3 deploy_flink.py --all

# Application
cd ../..
docker compose up -d
curl -X POST http://localhost:8000/simulation/start
```

**See**: [QUICK_START.md](QUICK_START.md)

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     Confluent Cloud                          │
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │    Kafka     │───▶│    Flink     │───▶│  Tableflow   │  │
│  │   Topics     │    │  Pipelines   │    │   (S3/Ice)   │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│         ▲                                          │         │
│         │                                          │         │
└─────────┼──────────────────────────────────────────┼─────────┘
          │                                          │
          │                                          ▼
┌─────────┴─────────────────────────────────────────────┐
│                  Local Environment                     │
│                                                        │
│  ┌──────────┐   ┌──────────┐   ┌──────────┐          │
│  │ Backend  │◀─▶│ Frontend │   │ Postgres │          │
│  │ (FastAPI)│   │  (Vue.js)│   │   (DB)   │          │
│  └──────────┘   └──────────┘   └──────────┘          │
│       │              │                                │
│       └──────────────┴────────────────────────────────┤
│                   Docker Compose                      │
└───────────────────────────────────────────────────────┘
                         │
                         ▼
                  ┌─────────────┐
                  │   Browser   │
                  │ (Analytics) │
                  └─────────────┘
```

---

## 📊 What Gets Deployed

### Confluent Cloud (Via Terraform)

- ✅ Environment (or use existing)
- ✅ Kafka Cluster (or use existing)
- ✅ Schema Registry (data source)
- ✅ Flink Compute Pool
- ✅ Service Account + API Keys
- ✅ Role Bindings (permissions)
- ✅ S3 Bucket + IAM (optional, for Tableflow)

### Data Pipelines (Via Python/dbt)

**Raw Layer** (3 tables):
- `hc_raw_patients` - Patient demographics
- `hc_raw_devices` - Device information
- `hc_raw_device_metrics` - Real-time telemetry

**RMD Layer** (7 tables):
- Sources: Patients, Devices, Prescriptions
- Dimensions: Patient dimension
- Facts: Telemetries, Anomalies, Drift events

### Application (Via Docker)

- ✅ Backend (FastAPI) - Port 8000
- ✅ Frontend (Vue.js) - Port 5173
- ✅ PostgreSQL - Port 5432
- ✅ Device Simulator (running)

### Analytics (Optional)

- ✅ Tableflow Connections (3)
- ✅ S3 Parquet Tables
- ✅ DuckDB Integration
- ✅ Real-time Dashboards

---

## 🎓 Learning Path

### For First-Time Users

1. Start with: **[QUICK_START.md](QUICK_START.md)**
2. Use automated script: `./deploy.sh`
3. Explore the UI: http://localhost:5173
4. Read architecture docs
5. Try manual deployment

### For Data Engineers

1. Read: **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)**
2. Study: **[pipelines/DBT_DEPLOYMENT_GUIDE.md](pipelines/DBT_DEPLOYMENT_GUIDE.md)**
3. Understand Flink SQL pipelines
4. Customize transformations
5. Add new tables

### For DevOps/SREs

1. Review: **[IaC/README.md](IaC/README.md)**
2. Understand Terraform structure
3. Set up CI/CD pipelines
4. Configure monitoring
5. Production hardening

### For Frontend Developers

1. Check: **[frontend/README.md](frontend/README.md)**
2. Explore Vue.js components
3. Chart.js integration
4. Real-time SSE streaming
5. UI customization

---

## 🔧 Common Tasks

### Deploy Everything

```bash
./deploy.sh --auto-approve
```

### Update Flink Pipelines

```bash
cd pipelines/flink_pipelines
python3 deploy_flink.py --all
```

### Restart Backend

```bash
docker compose restart backend
```

### View Logs

```bash
docker compose logs -f backend
```

### Check Status

```bash
# All services
docker compose ps

# Backend health
curl http://localhost:8000/health

# Simulation status
curl http://localhost:8000/simulation/status

# Analytics availability
curl http://localhost:8000/analytics/dashboard | jq '.available'
```

### Update Infrastructure

```bash
cd IaC
terraform plan
terraform apply
```

### Enable Tableflow

```bash
# 1. Get External ID from Confluent
# 2. Configure
cd IaC
nano aws/terraform.tfvars  # in IaC/aws: set enable_tableflow=true (separate state)

# 3. Deploy
terraform apply

# 4. Configure Tableflow in the Confluent UI (see IaC/README.md — Tableflow and S3)
```

---

## 🆘 Troubleshooting

### Quick Diagnostics

```bash
# Run automated checks
./deploy.sh --skip-terraform --skip-flink --skip-docker

# Check all components
curl http://localhost:8000/health
docker compose ps
terraform output -json | jq
```

### Common Issues

| Problem | Solution | Guide |
|---------|----------|-------|
| Terraform fails | Check credentials | [IaC/README.md](IaC/README.md) |
| Flink won't deploy | Source .env first | [pipelines/DBT_DEPLOYMENT_GUIDE.md](pipelines/DBT_DEPLOYMENT_GUIDE.md) |
| Docker won't start | Check port conflicts | [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md#troubleshooting) |
| No analytics data | Verify S3/local path | [IaC/README.md — Tableflow](IaC/README.md#tableflow-and-s3) |
| Simulation not working | Check Kafka connection | [backend/README.md](backend/README.md) |

### Get Help

1. Check logs: `docker compose logs backend`
2. Review documentation above
3. See troubleshooting sections
4. Check GitHub issues

---

## 📦 Deployment Artifacts

After successful deployment, you'll have:

### Configuration Files

- `IaC/terraform.tfstate` - Infrastructure state
- `backend/.env` - Backend configuration
- `backend/.env.terraform` - Terraform outputs
- `.terraform.lock.hcl` - Provider versions

### Running Services

- Confluent Cloud infrastructure
- Flink compute pool + statements
- Docker containers (3)
- Device simulation

### Data

- PostgreSQL prescriptions (5 records)
- Kafka topics (streaming data)
- Flink tables (10 total)
- S3 Parquet files (if Tableflow enabled)

---

## 🧹 Cleanup

### Stop Application

```bash
docker compose down
```

### Destroy Infrastructure

```bash
cd IaC
terraform destroy
```

### Complete Cleanup

```bash
# Stop and remove all
docker compose down -v  # Removes volumes too
cd IaC
terraform destroy       # Removes cloud infrastructure
```

---

## 📚 Additional Resources

- **Project Documentation**: https://jbcodeforce.github.io/healthcare-shift-left-demo
- **Confluent Flink Docs**: https://docs.confluent.io/cloud/current/flink/
- **dbt Documentation**: https://docs.getdbt.com/
- **FastAPI Docs**: https://fastapi.tiangolo.com/
- **Vue.js Guide**: https://vuejs.org/guide/

---

## 🎯 Quick Reference

### URLs

- Frontend: http://localhost:5173
- Backend: http://localhost:8000
- API Docs: http://localhost:8000/docs
- Analytics: http://localhost:5173/analytics
- Telemetry: http://localhost:5173/telemetry

### File Locations

- Infrastructure: `IaC/`
- Pipelines: `pipelines/`
- Backend: `backend/`
- Frontend: `frontend/`
- Docs: `docs/` or MkDocs

### Key Commands

```bash
# Deploy everything
./deploy.sh

# Update Flink
cd pipelines/flink_pipelines && python3 deploy_flink.py --all

# Restart backend
docker compose restart backend

# View logs
docker compose logs -f backend

# Check status
curl http://localhost:8000/health
```

---

**Deployment Time**: 30-60 minutes  
**Automation Level**: ~80% automated  
**Skill Level**: Beginner to Intermediate

**Start here**: [QUICK_START.md](QUICK_START.md) → [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
