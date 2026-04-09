# Quick Start - Healthcare Shift-Left Demo

**TL;DR**: Get the full demo running in ~30 minutes

## 🚀 Prerequisites Checklist

- [ ] Docker & Docker Compose installed
- [ ] Terraform installed
- [ ] Python 3.10+ installed
- [ ] Confluent Cloud account
- [ ] Confluent Cloud API credentials ready

## ⚡ Fast Track Deployment

### 1. Infrastructure (10 min)

```bash
cd IaC

# Configure
cp terraform.tfvars.example terraform.tfvars
nano terraform.tfvars  # Add your credentials

# Deploy
terraform init
terraform apply -auto-approve

# Export to backend
terraform output -raw backend_env_snippet >> ../backend/.env
```

### 2. Flink Pipelines (10 min)

```bash
cd ../pipelines/flink_pipelines

# Install dependencies
pip install requests

# Deploy
source ../../backend/.env
python3 deploy_flink.py --all
```

### 3. Application (5 min)

```bash
cd ../..

# Start services
docker compose up -d backend frontend postgres

# Start simulation
sleep 10
curl -X POST http://localhost:8000/simulation/start \
  -H "Content-Type: application/json" \
  -d '{"simulation_type": "all"}'
```

### 4. Verify

```bash
# Check status
curl http://localhost:8000/health
curl http://localhost:8000/simulation/status

# Open browser
open http://localhost:5173
open http://localhost:5173/analytics
```

## 📍 URLs

| Service | URL |
|---------|-----|
| **Frontend** | http://localhost:5173 |
| **Backend API** | http://localhost:8000/docs |
| **Analytics** | http://localhost:5173/analytics |
| **Telemetry** | http://localhost:5173/telemetry |

## 🎯 What You Get

After deployment:
- ✅ 5 simulated patients with devices
- ✅ Real-time telemetry streaming to Kafka
- ✅ 10 Flink tables processing data
- ✅ Anomaly detection with ML
- ✅ Interactive analytics dashboard
- ✅ Prescription management UI

## 🛠️ Common Commands

### Backend
```bash
# Restart backend
docker compose restart backend

# View logs
docker compose logs -f backend

# Stop simulation
curl -X POST http://localhost:8000/simulation/stop
```

### Flink
```bash
# Redeploy all pipelines
cd pipelines/flink_pipelines
python3 deploy_flink.py --all

# Deploy specific layer
python3 deploy_flink.py --layer raw
```

### Infrastructure
```bash
# Update infrastructure
cd IaC
terraform plan
terraform apply

# Get outputs
terraform output
```

## 🔍 Quick Diagnostics

```bash
# Check all services
docker compose ps

# Check environment
env | grep -E "KAFKA|FLINK|SCHEMA"

# Test API
curl http://localhost:8000/health
curl http://localhost:8000/analytics/dashboard | jq '.available'

# Check data
curl http://localhost:8000/telemetry/metrics | jq '. | length'
```

## 📖 Detailed Guide

For complete step-by-step instructions, see:
- **Full Deployment**: `DEPLOYMENT_GUIDE.md`
- **Terraform Setup**: `IaC/README.md`
- **Tableflow Guide**: `IaC/TABLEFLOW_SETUP_GUIDE.md`
- **dbt Deployment**: `pipelines/DBT_DEPLOYMENT_GUIDE.md`

## ⏱️ Time Breakdown

| Phase | Time | Automated? |
|-------|------|------------|
| Infrastructure (Terraform) | 10 min | ✅ Yes |
| Flink Pipelines | 10 min | ✅ Yes |
| Docker Services | 5 min | ✅ Yes |
| Tableflow (optional) | 15 min | ⚠️ Partial |
| **Total** | **30-45 min** | **Mostly** |

## 🆘 Quick Fixes

### "Terraform apply fails"
```bash
# Check credentials
terraform validate
cat terraform.tfvars
```

### "Docker won't start"
```bash
# Check ports
lsof -i :8000
lsof -i :5173
docker compose down && docker compose up -d
```

### "No data in dashboard"
```bash
# Restart simulation
curl -X POST http://localhost:8000/simulation/stop
curl -X POST http://localhost:8000/simulation/start

# Check logs
docker compose logs backend
```

### "Flink deployment fails"
```bash
# Verify env vars
source backend/.env
env | grep FLINK

# Check Flink compute pool
confluent flink compute-pool list
```

## 🎓 Learning Path

1. **Start here**: Quick Start (this file)
2. **Go deeper**: DEPLOYMENT_GUIDE.md
3. **Understand Flink**: pipelines/DBT_DEPLOYMENT_GUIDE.md
4. **Add Tableflow**: IaC/TABLEFLOW_SETUP_GUIDE.md
5. **Explore code**: Backend/Frontend READMEs

---

**Questions?** See `DEPLOYMENT_GUIDE.md` for detailed troubleshooting.
