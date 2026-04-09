# Healthcare Shift-Left Demo - Setup Guide
## 🎯 What's Available

### 1. Analytics Dashboard (http://localhost:5173/analytics)

View metrics from pre-loaded sample data:
- **Anomalies per device** - Bar chart showing which devices have anomalies
- **Configuration changes over time** - Time series of prescription changes
- **New devices deployed over time** - Device registration timeline

**Data Source**: Sample Parquet files in `analytics/sample-data/parquet/`

### 2. Real-Time Telemetry (http://localhost:5173/telemetry)

View live device metrics streaming from Kafka:
- Device telemetry data (pressure, flow rate, flow level)
- Real-time charts
- Server-Sent Events (SSE) stream

**Data Source**: Live Kafka stream from Confluent Cloud

### 3. Prescriptions Management (http://localhost:5173/prescriptions)

View and manage device prescriptions:
- List all prescriptions
- View prescription details
- CRUD operations via API

**Data Source**: PostgreSQL database

## 🔧 Configuration

The application is pre-configured with:

✅ **Kafka** - Confluent Cloud cluster (lkc-2p03qy)  
✅ **Schema Registry** - Confluent Schema Registry  
✅ **PostgreSQL** - Local Docker container  
✅ **Analytics** - Local Parquet files

All configuration is in `backend/.env`. The credentials are already set up.

## 🎮 Testing the Application


### Trigger Device Anomalies

Simulate specific device scenarios:

```bash
# Flow level drop on DEV-P001
curl -X POST "http://localhost:8000/device/DEV-P001/simulator/flow_level_down"

# Pressure oscillation on DEV-P003
curl -X POST "http://localhost:8000/device/DEV-P003/simulator/pressure_oscillate"

# Flow rate drop on DEV-P005
curl -X POST "http://localhost:8000/device/DEV-P005/simulator/flow_rate_down"
```

### Add a New Prescription

```bash
curl -X POST http://localhost:8000/prescriptions \
  -H "Content-Type: application/json" \
  -d '{
    "patient_id": "P001",
    "device_id": "DEV-P001",
    "medication_or_therapy": "Updated CPAP Settings",
    "parameters": [
      {
        "parameter_name": "Pressure",
        "parameter_value": 12.0,
        "parameter_type": "float",
        "parameter_tolerance": 1.5
      },
      {
        "parameter_name": "FlowRate",
        "parameter_value": 3.0,
        "parameter_type": "float",
        "parameter_tolerance": 0.5
      }
    ]
  }'
```

### View Analytics Data

```bash
# Get all analytics in one call
curl http://localhost:8000/analytics/dashboard | jq

# Get specific metrics
curl http://localhost:8000/analytics/anomalies-per-device | jq
curl http://localhost:8000/analytics/config-changes-over-time | jq
curl http://localhost:8000/analytics/new-devices-over-time | jq
```

## 📊 Understanding the Data Flow

```
PostgreSQL (prescriptions)
        │
        ├──────────────────┐
        │                  │
        ▼                  ▼
Backend Simulator ──► Kafka Topic (hc_raw_device_metrics)
                            │
                            ▼
                      Flink Pipelines
                      • hc_fct_dev_anomaly (anomaly detection)
                      • hc_fct_drift_evts (drift detection)
                      • hc_fct_telemetries (telemetry processing)
                            │
                            ▼
                      S3 Parquet Tables ──► Analytics Dashboard
                      (via DuckDB)
```

### Current Demo Data:

- **5 Patients**: P001 to P005
- **5 Devices**: DEV-P001 to DEV-P005
- **5 Prescriptions**: One per patient-device pair
- **Sample Analytics**: 9 anomalies, 9 config changes, 7 device registrations

## 🛠️ Troubleshooting

### Port Already in Use

If you see "port is already allocated" errors:

```bash
# Check what's using port 5432, 8000, or 5173
lsof -i :5432
lsof -i :8000
lsof -i :5173

# Stop conflicting services or change ports in docker-compose.yml
```

### Services Not Starting

```bash
# View logs for a specific service
docker compose logs backend
docker compose logs frontend
docker compose logs postgres

# Follow logs in real-time
docker compose logs -f backend

# Restart all services
docker compose restart
```

### Analytics Dashboard Shows "Not Available"

Check that the analytics volume is mounted:

```bash
# Verify the parquet files exist
ls -la analytics/sample-data/parquet/

# Should see:
# - anomalies.parquet
# - device_first_seen.parquet
# - prescription_changes.parquet
```

### Kafka Connection Issues

The Kafka credentials are pre-configured in `backend/.env`. If you need to verify:

```bash
# Check backend logs for Kafka errors
docker compose logs backend | grep -i kafka

# Verify env variables are loaded
docker exec backend env | grep KAFKA
```

## 🔄 Stopping and Cleaning Up

```bash
# Stop all services
docker compose down

# Stop and remove volumes (cleans database)
docker compose down -v

# Remove all containers and networks
docker compose down --remove-orphans
```

## 📖 Additional Resources

- **Main Documentation**: See `README.md` in the project root
- **API Documentation**: http://localhost:8000/docs (when backend is running)
- **MkDocs Site**: Run `mkdocs serve` to view full documentation
- **Flink Pipelines**: See `pipelines/` directory for SQL pipeline definitions

## 🎯 Next Steps

After getting familiar with the demo:

1. **Deploy Flink Pipelines** - Process live Kafka data to create real analytics
2. **Configure S3** - Store analytics data in S3 instead of local Parquet files
3. **Add More Devices** - Extend the simulation with more patients and devices
4. **Customize Pipelines** - Modify Flink SQL to add new metrics or transformations

## 💡 Key Features Demonstrated

✅ **CDC with Debezium** - Capture prescription changes from PostgreSQL  
✅ **Kafka Streaming** - Real-time device telemetry  
✅ **Flink SQL** - Stream processing with ML-based anomaly detection  
✅ **Schema Registry** - Avro schema management  
✅ **DuckDB Analytics** - Query Parquet files from S3  
✅ **Vue.js Frontend** - Interactive dashboards with Chart.js  
