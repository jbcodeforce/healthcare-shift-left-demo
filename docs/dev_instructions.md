# Development Instructions

This document describes:

* how to run the healthcare shift left demo locally during development
* the codebase structure
* the solution design.

It is intended for developers who need to modify or extend this code base.

---
## Understanding the main components

From the figure below, the green components run locally with docker compose, the Confluent Environment, Kafka cluster, Flink Compute pools, Terraform are created via Terraform, and the S3 bucket, IAM role and access policies are done using AWS concole.

![](./images/demo_components.drawio.png)

### Backend
The **backend** is the demo API and telemetry Kafka producer: REST endpoints for patients, devices, and prescriptions, plus simulation control and telemetry SSE.

### Frontend

A Vue.js control plane runs in `frontend/` and provides a home page with left navigation (Patients, Devices, Prescriptions, Device telemetry), plus simulation control and live telemetry stream.

The app expects the backend API at `http://localhost:8000` by default. Override with `VITE_API_URL` (e.g. in `frontend/.env`). The control plane fetches patients, devices, and prescriptions from the backend and lets you start/stop the device simulation and connect to the live telemetry SSE stream.

### Kafka Connect and Debezium

**Kafka Connect** runs in the same Docker Compose stack and streams **PostgreSQL CDC** (change data capture) to **Confluent Cloud Kafka** using the **Debezium PostgreSQL** connector. It uses the same Confluent credentials as the backend (Kafka bootstrap servers, API key/secret as `KAFKA_SASL_USERNAME`/`KAFKA_SASL_PASSWORD`, and Schema Registry). No local Kafka broker is required.

**Postgres**: The Compose Postgres service is started with `wal_level=logical` for logical decoding. An init script grants `REPLICATION` to the app user so Debezium can create replication slots. If the database was created before adding this setup, run once: `ALTER USER demo WITH REPLICATION;` (or your `POSTGRES_USER`) inside Postgres.

## Prerequisites

- **Docker & Docker Compose** — for Postgres, optional backend/frontend/Connect containers.
- **Node.js & npm** — for running the frontend in dev mode (Vite).
- **Python 3.10+ with uv** — for running the backend in dev mode (recommended). Alternatively use the backend Docker image.
- **Confluent Cloud** — Kafka cluster and Schema Registry for device telemetry and Debezium CDC. The demo can run without Kafka for local UI and API testing; simulation, Kafka Connect, and Flink Statment deployment will require credentials.


### Environment (backend)

Copy and edit the backend `.env` environment file:

```bash
cp backend/.env.example backend/.env
# Edit backend/.env with the minimum configuration
CLOUD_PROVIDER="aws"
CLOUD_REGION="us-west-2"
ORG_ID="4....4"
CONFLUENT_CLOUD_API_KEY=.....
CONFLUENT_CLOUD_API_SECRET=cflt....
```

For **PostgreSQL** (prescriptions CRUD and Debezium), the Compose stack uses `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` (defaults: `demo`, `demo`, `healthcare`). For local backend dev, set `DATABASE_URL=postgresql://demo:demo@localhost:5432/healthcare` (or match your Postgres credentials if you change them).

The IaC folder includes terraforms to create a new Confluent Cloud Environment, kafka cluster.. or use an existing one. [See quickstart](./quick_start.md/#infrastructure-as-code) section.

## How to run the demo

Set environment variables:
```sh
source set_env_var
```

### Option A: One-command dev mode (recommended for developers)

The `./start_dev_mode.sh` script, starts Postgres via Docker, then the backend (uvicorn) and frontend (Vite) on the host so you can edit code and see changes immediately.

```bash
# From repo root; ensure backend/.env exists (at least DATABASE_URL if using Postgres)
./start_dev_mode.sh
```

This script:

1. Checks for `uv`, `node`, `npm`.
2. Starts **Postgres** with `docker compose up postgres -d`.
3. **Kafka Connect (optional):** If `backend/.env` exists, checks whether Kafka Connect is running; if not, starts it with `docker compose --env-file backend/.env up kafka-connect -d`. Waits for Connect to be ready, then verifies the Debezium connector `debezium-postgres-healthcare` is defined and registers it via `./connect/register-connector.sh` if missing. If Kafka credentials are not set or Connect fails to start, the script continues without failing.
4. Starts the **backend** with `uv run uvicorn backend.main:app --host 0.0.0.0 --port 8000` from `backend/`.
5. Starts the **frontend** with `npm run dev` from `frontend/` (Vite on port 5173).

The first time it may take some time as it downloads docker images and builds local kafka connector images.

**URLs:**

| Service       | URL                      |
|---------------|--------------------------|
| Frontend      | http://localhost:5173    |
| Backend       | http://localhost:8000    |
| API docs      | http://localhost:8000/docs |
| Kafka Connect | http://localhost:8083 (if started) |
| Postgres      | localhost:5432 (internal) | 

Stop with **Ctrl+C**; the script stops backend, frontend, and runs `docker compose down`.

### Option B: Backend and frontend manually

**1. Postgres (required for prescriptions CRUD and Debezium):**

```bash
docker compose up postgres -d
```

**2. Backend (from repo root):**

```bash
cd backend
export DATABASE_URL=postgresql://demo:demo@localhost:5432/healthcare   # if not in .env
uv run uvicorn backend.main:app --host 0.0.0.0 --port 8000
```

**3. Frontend (new terminal):**

```bash
cd frontend
npm install
npm run dev
```

Open http://localhost:5173. The frontend proxies `/api` to `http://localhost:8000` (see `frontend/vite.config.js`).

### Option C: Full stack with Docker Compose

Runs backend, frontend, Postgres, and (optionally) Kafka Connect as containers. Best for parity with a deployed environment.

```bash
# Ensure backend/.env has Kafka/Schema Registry and Postgres vars for Compose
docker compose --env-file backend/.env up -d

# Optional: Kafka Connect (Debezium) for prescriptions CDC
docker compose --env-file backend/.env up -d kafka-connect
./connect/register-connector.sh
```

- **Frontend:** http://localhost:5173 (served by container on port 80, mapped to 5173).
- **Backend:** http://localhost:8000.

### Running Kafka Connect

Kafka Connect (with the Debezium PostgreSQL connector) streams changes from the local `prescriptions` table to Confluent Cloud Kafka. It requires Kafka and Schema Registry credentials in `backend/.env`.

**When using `./start_dev_mode.sh`:** The script automatically assesses whether Connect is running; if not, it starts the Connect container, waits for the REST API, then checks if the connector `debezium-postgres-healthcare` is defined and registers it when missing. If `backend/.env` is absent or Connect fails to start (e.g. invalid Kafka config), the script continues without failing.

**Manual run:**

1. Create the target topic with script, as the debezium does not seem to create the topic automatically
   ```sh
   ```

1. **Start Connect** (from repo root, with `backend/.env` containing Kafka and Schema Registry vars):
   ```bash
   docker compose --env-file backend/.env up -d kafka-connect
   ```

2. **Wait for the REST API** (e.g. `curl -s http://localhost:8083/connectors` returns JSON).

3. **Register the connector** if it is not already defined:
   ```bash
   ./connect/register-connector.sh
   ```
   Optionally set `CONNECT_URL` if Connect is not on port 8083:
   ```bash
   CONNECT_URL=http://localhost:8083 ./connect/register-connector.sh
   ```

4. **Check connector status:**
   ```bash
   curl -s http://localhost:8083/connectors/debezium-postgres-healthcare/status | jq .
   ```

**Connector name:** `debezium-postgres-healthcare`. It uses `database.hostname=postgres` (Docker service name), so Connect must run in the same Compose network as Postgres. The script `connect/register-connector.sh` sources `backend/.env` for connector settings (see `connect/README.md`).

**Schema subject prefix (converter level):** The backend producer uses a subject name format `:{prefix}:{topic}-key` (see `backend/src/backend/producer.py` and `schema_subject_prefix` in config). Connect uses the same format via a custom **PrefixTopicNameStrategy** (built in the Connect image from `connect/subject-strategy/`). Set `SCHEMA_SUBJECT_PREFIX` in `backend/.env` (e.g. `.flink-dev`); the default in Compose is `.flink-dev`. The strategy reads the prefix from converter config and, if missing, from the JVM system property `connect.subject.name.prefix` (set by the Connect entrypoint from `SCHEMA_SUBJECT_PREFIX`). After changing the strategy code or prefix, rebuild the Connect image and restart: `docker compose build kafka-connect && docker compose up -d kafka-connect --force-recreate`. Then confirm in Schema Registry that subjects like `:.flink-dev:healthcare.public.prescriptions-key` and `:.flink-dev:healthcare.public.prescriptions-value` exist.

**Schema Registry context via URL (optional):** To use a named context in the Schema Registry URL, set `SCHEMA_REGISTRY_CONTEXT` in `backend/.env`. The Connect entrypoint will then append `/contexts/{context}` to the Schema Registry URL.

**Publication (required for Debezium):** The connector uses the existing publication `debezium_healthcare` for `public.prescriptions`. Postgres init scripts (`postgres/init.d/01-prescriptions-schema.sql` and `02-debezium-replication.sh`) create the table and publication on first start. If you had Postgres running before that, create the publication manually: `docker exec -it postgres psql -U demo -d healthcare -c "CREATE PUBLICATION IF NOT EXISTS debezium_healthcare FOR TABLE public.prescriptions;"`. See `connect/README.md` for full troubleshooting.


**Troubleshooting (Connect not visible on port 8083):**

- **Check whether the container is running:** `docker ps -a | grep kafka-connect`. If it is restarting or exited, inspect logs: `docker logs kafka-connect` (or `docker compose logs kafka-connect` from repo root). Common causes: invalid or missing `KAFKA_BOOTSTRAP_SERVERS`, `KAFKA_SASL_USERNAME`, `KAFKA_SASL_PASSWORD`, or Schema Registry URL/auth in `backend/.env`; or Confluent Cloud rejecting creation of Connect internal topics (config/offset/status) with the configured replication factor.
- **REST API binding:** The Compose file sets `CONNECT_LISTENERS=http://0.0.0.0:8083` and `CONNECT_REST_PORT=8083` so the REST API listens on all interfaces inside the container; port `8083` is mapped to the host. If you changed the port mapping, set `CONNECT_URL` accordingly when calling `register-connector.sh`.
- **Confluent Cloud:** Internal topics use replication factor `3` by default in this project to match Confluent Cloud expectations. If your cluster has different requirements, adjust `CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR`, `CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR`, and `CONNECT_STATUS_STORAGE_REPLICATION_FACTOR` in `docker-compose.yml`.
- **Reachability:** From the host, use `curl -s http://localhost:8083/connectors`. If that fails, the container may still be starting (healthcheck allows a 45s start period) or the worker may have crashed—check logs as above.

- **401 Unauthorized when registering Avro schema:** The Connect worker must send Schema Registry credentials when the Avro converter registers schemas. The Compose file sets `CONNECT_*_SCHEMA_REGISTRY_BASIC_AUTH_CREDENTIALS_SOURCE=USER_INFO` so the converter uses the provided user info. Ensure `SCHEMA_REGISTRY_BASIC_AUTH_USER_INFO` in `backend/.env` is the **Schema Registry** API key and secret in the form `key:secret` (Confluent Cloud uses a dedicated Schema Registry API key, not the Kafka cluster API key). If the secret contains colons or special characters, use single quotes in `.env`, e.g. `SCHEMA_REGISTRY_BASIC_AUTH_USER_INFO='sr_key:sr_secret'`. Restart the Connect container after changing `.env`: `docker compose --env-file backend/.env up -d kafka-connect --force-recreate`.

---

## Code structure

### Repository layout

```
healthcare-shift-left-demo/
├── backend/                 # FastAPI REST API + telemetry simulation
│   ├── src/backend/         # Python package
│   ├── tests/
│   ├── pyproject.toml
│   ├── .env.example
│   └── Dockerfile
├── frontend/                # Vue 3 + Vite SPA
│   ├── src/
│   ├── package.json
│   ├── vite.config.js
│   └── Dockerfile
├── connect/                 # Kafka Connect + Debezium
│   ├── register-connector.sh
│   ├── debezium-postgres.json
│   └── Dockerfile
├── pipelines/               # Flink SQL (raw + RMD layers)
│   ├── raw/                 # e.g. device_metrics, raw_patients, raw_devices, 
│   └── rmd/                 # e.g. src_patients, src_devices, src_prescriptions
├── postgres/                # Postgres init scripts (e.g. replication role)
├── docs/
├── docker-compose.yml
├── start_dev_mode.sh
└── README.md
```

### Backend (`backend/`)

| Path | Purpose |
|------|--------|
| `src/backend/main.py` | FastAPI app: health, patients, devices, prescriptions CRUD, simulation control, telemetry SSE and metrics API. |
| `src/backend/simulation.py` | Device telemetry simulation loop (Pressure, FlowRate, MotorSpeed). Produces to Kafka, pushes to SSE queue, and maintains a cache for `GET /telemetry/metrics`. |
| `src/backend/producer.py` | Confluent Kafka Avro producer; sends device metrics to `device_metrics` topic. |
| `src/backend/schema.py` | Avro schema and `DeviceMetricsValue` model for telemetry. |
| `src/backend/data.py` | In-memory demo data for patients and devices; used when DB is not configured or for seeding. |
| `src/backend/db.py` | PostgreSQL prescriptions table and CRUD (create, read, update, delete, seed). |
| `src/backend/config.py` | Pydantic settings: Kafka, Schema Registry, simulation interval/count, `DATABASE_URL`. |

**Key APIs:**


See last version of the OpenAPI doc [at localhost:8000/docs](http://localhost:8000/docs)

### Frontend (`frontend/src/`)

| Path | Purpose |
|------|--------|
| `main.js` | App bootstrap; mounts Vue app. |
| `App.vue` | Root component; router view. |
| `router/index.js` | Vue Router routes (e.g. `/`, `/patients`, `/devices`, `/prescriptions`, `/telemetry`, `/demonstration`). |
| `layouts/DefaultLayout.vue` | Shell with sidebar navigation. |
| `api/deviceGenerator.js` | API client: patients, devices, prescriptions, simulation, `getTelemetryMetrics()`, `subscribeTelemetryStream()` (SSE). |
| `views/HomeView.vue` | Home page. |
| `views/PatientsView.vue`, `views/DevicesView.vue` | List views. |
| `views/PrescriptionsView.vue` | Prescriptions list and form (grouped by device); create/update/delete. |
| `views/TelemetryView.vue` | Simulation control, metrics charts (Pressure, Flow rate, Motor speed), live telemetry table (SSE). |
| `views/DemonstrationView.vue` | Demonstration copy and steps (content from `content/demonstration.js`). |
| `style.css` | Global styles and CSS variables. |

The frontend talks only to the backend; it does not connect to Kafka or Postgres directly.

### Pipelines (`pipelines/`)

Flink SQL definitions for Confluent Cloud (or compatible Flink):

- **raw/** — Raw Kafka-backed tables and DDL/DML: `device_metrics`, `raw_patients`, `raw_devices`, `raw_prescriptions`.
- **rmd/** — Refined/source tables: `src_patients`, `src_devices`, `src_prescriptions`.

Used with the shift-left tool (see README) for deployment. Not required for running the backend or frontend locally.

### Connect (`connect/`)

- **register-connector.sh** — Registers the Debezium PostgreSQL connector (`debezium-postgres-healthcare`) with Kafka Connect using `backend/.env` for Postgres and Connect URL.
- **debezium-postgres.json** — Connector config (topic prefix `healthcare`, table `prescriptions`).
- **Dockerfile** — Kafka Connect image with Debezium.


### cleaning everything

From the repo root, **`./clean_all.sh`** stops anything on ports **8000** and **5173**, runs **`docker compose down -v`** (wipes the Postgres volume), removes **`backend/.venv`** and **`.venv`**, and—if **`shift_left`** is on your **`PATH`**—runs **`shift_left pipeline undeploy`** for each fact tables. Source **`set_j9r_env_sl`** (or set **`FLINK_COMPUTE_POOL_ID`**) before running if undeploy needs Confluent credentials.

- **`./clean_all.sh --keep-volumes`** — same as above but **`docker compose down`** without **`-v`** (keeps Postgres data).

---

## Solution design

You typically need some main entities to show a meaningful "Patient Journey" in a stream: the Patient, the Provider, the Medical device and the Prescription. We want to measure drift. CPAPs/Ventilators-style devices, prescription drift can indicate:

* Mask Leak: If the pressure required to maintain airflow increases significantly, the mask may be fitted poorly.
* Patient Condition Change: If the patient's airway resistance changes, the device may no longer be providing effective therapy at the original prescribed level.
* Mechanical Wear: The motor may be failing to reach the target RPMs required for the prescribed pressure.

### A. Patient Class

This represents the static/slow-moving dimensions of the person.

```Java
public class Patient {
    public String patientId;   // Primary Key
    public String name;
    public String gender;
    public String birthDate;
    public String zipCode;     // Useful for Flink geo-aggregations
    
    // Default constructor for Flink/POJO serialization
    public Patient() {}
}
```

The Patient may have a device assigned to.

```java
public class Device {
   public String device_id;
   public String patientId;
   public double preassureSetting;
   public double flowRateSetting;
   public int flowLevel;
}
```


### B. Prescription Class

The "Desired State". It tells Flink what the device should be doing.

```Java
public class Prescription {
    public String prescriptionId;
    public String patientId;
    public String deviceId;
    public String medicationOrTherapy; // e.g., "CPAP Oxygen Flow"
    public String metricName;
    public double targetValue;          // e.g., 2.5 (Liters per minute)
    public double toleranceRange;      // e.g., 0.5 (Acceptable +/-)
    public long startDate;
    public long endDate;
    
    public Prescription() {}
}
```

### C. DeviceTelemetry 
The "Observed State": This is the high-velocity stream coming from the hardware.

```Java
public class DeviceTelemetry {
    public String deviceId;
    public String patientId;
    public long timestamp;
    public String metricName;          // e.g.,"Pressure"
    public double metricValue;
    public String softwareVersion;     // Crucial for manufacturers (debugging)
    
    public DeviceTelemetry() {}
}
```

### D. Drift Alert
```java
public class DriftAlert {
    public String deviceId;
    public String patientId;
    public String message;
    public double prescribedValue;
    public double actualValue;
}
```

### HealthProvider Class (Future extension)
This represents the doctor.

```Java
public class HealthProvider {
    public String providerId;
    public String organizationName;
    public String specialty;   // e.g., "Cardiology", "General Practice"
    public String NPI;         // National Provider Identifier
    
    public HealthProvider() {}
}
```

### Encounter ( (Future extension)
This is the "Fact" table that will flow through your Kafka topic. It is the most important class for Flink because it contains the timestamps.

```Java
public class Encounter {
    public String encounterId;
    public String patientId;    // Foreign Key to Patient
    public String providerId;   // Foreign Key to Provider
    public long timestamp;      // Event time for Flink Windowing
    public String type;         // e.g., "Inpatient", "Ambulatory", "Emergency"
    public double cost;         // For "Sum" or "Avg" aggregations
    public String diagnosisCode; // ICD-10 code
    
    public Encounter() {}
}
```


### High-level data flow

1. **Prescriptions (command/intent)**  
   Stored in **PostgreSQL**. The UI and API perform CRUD. **Debezium** (Kafka Connect) streams changes to Confluent Cloud Kafka (e.g. `healthcare.public.prescriptions`). Downstream Flink jobs can consume this as the “desired state.”

2. **Device telemetry (reality)**  
   The **backend simulation** generates records (Pressure, FlowRate, MotorSpeed) per device at a configurable interval. Each record is:
   - Sent to **Kafka** (topic `device_metrics`, Avro, Schema Registry).
   - Pushed to an in-memory **queue** for **SSE** (`GET /telemetry/stream`).
   - Appended to a **bounded cache** used by **GET /telemetry/metrics** for the telemetry charts.

3. **Frontend**  
   The Vue app calls the backend REST API for patients, devices, prescriptions, and simulation control. It subscribes to the telemetry SSE stream for the live table and polls `GET /telemetry/metrics` to drive the three time-series charts (one line per device, time on the x-axis).

### Telemetry path (simulation → Kafka + UI)

```
simulation.py (_run_loop)
  → produce_device_metric(rec)     → Kafka (device_metrics)
  → _emit_telemetry(rec)          → _telemetry_cache (deque, last N)
                                 → _telemetry_queue (for SSE)
main.py
  → _broadcast_telemetry()        → each SSE subscriber queue
  → GET /telemetry/metrics        → get_cached_telemetry()
  → GET /telemetry/stream         → SSE generator reading from subscriber queue
```

- **Cache size:** Configurable in `simulation.py` (`TELEMETRY_CACHE_MAXLEN`, default 200). Ensures the metrics API returns enough history for 5–10 devices and multiple ticks.
- **Simulation:** Runs in a background thread; number of patients/devices and interval come from `config.py` (env: `SIMULATION_NUM_PATIENTS`, `SIMULATION_INTERVAL_SECONDS`).

### Prescriptions and CDC

- Prescriptions are created/updated/deleted via API and stored in Postgres. If `DATABASE_URL` is not set, the API can still serve in-memory demo prescriptions (no CRUD).
- When Kafka Connect and the Debezium connector are running, inserts/updates/deletes on the prescriptions table are captured and published to Kafka. Flink (or other consumers) can join this stream with device telemetry to detect “prescription drift” (e.g. telemetry outside target ± tolerance).


--- 
## Deployment

* Be sure to have set env variables. See[.env.example]()

### With shift_left cli

Need to be on at least shift_left version 0.1.49

```sh
source set_sl_env
shift_left table build-inventory $PIPELINES
shift_left pipeline delete-all-metadata
shift_left pipeline build-all-metadata
shift_left pipeline  build-execution-plan --table-name hc_fct_drift_evts --compute-pool-id $FLINK_COMPUTE_POOL_ID 
```

Here is an example of outcomes
```sh
--- Ancestors: 7 ---
Statement Name                                                  Status          Compute Pool    Action  Upgrade Mode    Table Name
-----------------------------------------------------------------------------------------------------------------------------------------------------------
dev-usw2-rmd-dml-hc-src-prescriptions                           UNKNOWN         lfcp-916r8m     To run  Stateless       hc_src_prescriptions
dev-usw2-raw-dml-hc-raw-device-metrics                          UNKNOWN         lfcp-916r8m     To run  Stateless       hc_raw_device_metrics
dev-usw2-raw-dml-hc-raw-patients                                UNKNOWN         lfcp-916r8m     To run  Stateless       hc_raw_patients
dev-usw2-raw-dml-hc-raw-devices                                 UNKNOWN         lfcp-916r8m     To run  Stateless       hc_raw_devices
dev-usw2-rmd-dml-hc-src-patients                                UNKNOWN         lfcp-916r8m     To run  Stateful        hc_src_patients
dev-usw2-rmd-dml-hc-src-devices                                 UNKNOWN         lfcp-916r8m     To run  Stateless       hc_src_devices
dev-usw2-rmd-dml-hc-dim-patients                                UNKNOWN         lfcp-916r8m     To run  Stateful        hc_dim_patients

--- Children to restart ---
Statement Name                                                  Status          Compute Pool    Action  Upgrade Mode    Table Name
-----------------------------------------------------------------------------------------------------------------------------------------------------------
dev-usw2-rmd-dml-hc-fct-drift-evts                              UNKNOWN         lfcp-916r8m     Restart Stateful        hc_fct_drift_evts
```

* Deploy:
   ```sh
   shift_left pipeline deploy --table-name hc_fct_drift_evts --compute-pool-id $FLINK_COMPUTE_POOL_ID 
   ```

## 