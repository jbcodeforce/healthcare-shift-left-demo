# Development instructions

This document describes how to run the healthcare shift left demo locally, the codebase structure, and the solution design. It is intended for developers who need to modify or extend the demo.

---

## Table of contents

1. [Prerequisites](#prerequisites)
2. [How to run the demo](#how-to-run-the-demo)
3. [Running Kafka Connect](#running-kafka-connect)
4. [Code structure](#code-structure)
5. [Solution design](#solution-design)

---

## Prerequisites

- **Docker & Docker Compose** — for Postgres, optional backend/frontend/Connect containers.
- **Node.js & npm** — for running the frontend in dev mode (Vite).
- **Python 3.10+ with uv** — for running the backend in dev mode (recommended). Alternatively use the backend Docker image.
- **Confluent Cloud** — Kafka cluster and Schema Registry for device telemetry and Debezium CDC. The demo can run without Kafka for local UI and API testing; simulation, Kafka Connect, and Flink Statment deployment will require credentials.

### Environment (backend)

Copy and edit the backend environment file:

```bash
cp backend/.env.example backend/.env
# Edit backend/.env with:
# - KAFKA_BOOTSTRAP_SERVERS, KAFKA_SASL_USERNAME, KAFKA_SASL_PASSWORD (if using Kafka)
# - SCHEMA_REGISTRY_URL, SCHEMA_REGISTRY_BASIC_AUTH_USER_INFO (if using Schema Registry)
# - DATABASE_URL or rely on Compose: postgresql://demo:demo@localhost:5432/healthcare
```

For **PostgreSQL** (prescriptions CRUD and Debezium), the Compose stack uses `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` (defaults: `demo`, `demo`, `healthcare`). For local backend dev, set `DATABASE_URL=postgresql://demo:demo@localhost:5432/healthcare` (or match your Postgres credentials if you change them).

---

## How to run the demo

### Option A: One-command dev mode (recommended for developers)

Starts Postgres via Docker, then the backend (uvicorn) and frontend (Vite) on the host so you can edit code and see changes immediately.

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

Kafka Connect (with the Debezium PostgreSQL connector) streams changes from the local `prescriptions` table to Confluent Cloud Kafka. It is **optional** and requires Kafka and Schema Registry credentials in `backend/.env`.

**When using `./start_dev_mode.sh`:** The script automatically assesses whether Connect is running; if not, it starts the Connect container, waits for the REST API, then checks if the connector `debezium-postgres-healthcare` is defined and registers it when missing. If `backend/.env` is absent or Connect fails to start (e.g. invalid Kafka config), the script continues without failing.

**Manual run:**

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

**Topic pre-creation:** If the connector logs `UNKNOWN_TOPIC_OR_PARTITION` for `healthcare.public.prescriptions`, create the topic before (or after) starting the connector. With Confluent Cloud CLI: `ccloud kafka topic create healthcare.public.prescriptions --partitions 1`. Or run `./connect/create-topics.sh` (requires `ccloud`). See `connect/README.md` for topic naming.

**Troubleshooting (Connect not visible on port 8083):**

- **Check whether the container is running:** `docker ps -a | grep kafka-connect`. If it is restarting or exited, inspect logs: `docker logs kafka-connect` (or `docker compose logs kafka-connect` from repo root). Common causes: invalid or missing `KAFKA_BOOTSTRAP_SERVERS`, `KAFKA_SASL_USERNAME`, `KAFKA_SASL_PASSWORD`, or Schema Registry URL/auth in `backend/.env`; or Confluent Cloud rejecting creation of Connect internal topics (config/offset/status) with the configured replication factor.
- **REST API binding:** The Compose file sets `CONNECT_LISTENERS=http://0.0.0.0:8083` and `CONNECT_REST_PORT=8083` so the REST API listens on all interfaces inside the container; port `8083` is mapped to the host. If you changed the port mapping, set `CONNECT_URL` accordingly when calling `register-connector.sh`.
- **Confluent Cloud:** Internal topics use replication factor `3` by default in this project to match Confluent Cloud expectations. If your cluster has different requirements, adjust `CONNECT_CONFIG_STORAGE_REPLICATION_FACTOR`, `CONNECT_OFFSET_STORAGE_REPLICATION_FACTOR`, and `CONNECT_STATUS_STORAGE_REPLICATION_FACTOR` in `docker-compose.yml`.
- **Reachability:** From the host, use `curl -s http://localhost:8083/connectors`. If that fails, the container may still be starting (healthcheck allows a 45s start period) or the worker may have crashed—check logs as above.

- **401 Unauthorized when registering Avro schema:** The Connect worker must send Schema Registry credentials when the Avro converter registers schemas. The Compose file sets `CONNECT_*_SCHEMA_REGISTRY_BASIC_AUTH_CREDENTIALS_SOURCE=USER_INFO` so the converter uses the provided user info. Ensure `SCHEMA_REGISTRY_BASIC_AUTH_USER_INFO` in `backend/.env` is the **Schema Registry** API key and secret in the form `key:secret` (Confluent Cloud uses a dedicated Schema Registry API key, not the Kafka cluster API key). If the secret contains colons or special characters, use single quotes in `.env`, e.g. `SCHEMA_REGISTRY_BASIC_AUTH_USER_INFO='sr_key:sr_secret'`. Restart the Connect container after changing `.env`: `docker compose --env-file backend/.env up -d kafka-connect --force-recreate`.

### Frontend API base URL

- **Dev (Vite):** The app uses `apiBase = '/api'` when `VITE_API_URL` is not set; Vite proxies `/api` to the backend (see `frontend/vite.config.js`).
- **Production / custom backend:** Set `VITE_API_URL` (e.g. in `frontend/.env`) to the backend origin (e.g. `http://localhost:8000`).

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

- `GET /health` — liveness.
- `GET /patients`, `GET /devices` — demo data.
- `GET /prescriptions`, `GET /prescriptions/{id}`, `POST /prescriptions`, `PUT /prescriptions/{id}`, `DELETE /prescriptions/{id}` — prescriptions (require Postgres).
- `GET /simulation/status`, `POST /simulation/start`, `POST /simulation/stop` — simulation control.
- `GET /telemetry/metrics` — last N cached telemetry records (for charts).
- `GET /telemetry/stream` — Server-Sent Events stream of live telemetry.

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

---

## Solution design

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

### Design choices

- **Single backend** as the gateway for the frontend: no direct Kafka or DB access from the browser; simpler auth and CORS.
- **SSE for live telemetry** so the UI can show a real-time stream without polling; **polling** is used only for the metrics charts (`/telemetry/metrics`) to keep implementation simple and avoid overloading the SSE path.
- **In-memory telemetry cache** so the metrics API does not depend on Kafka consumer lag or external storage; it reflects exactly what the simulator has sent recently.
- **Avro + Schema Registry** for Kafka so Confluent Cloud and Flink can use consistent schemas for `device_metrics` and CDC topics.

For domain model (Patient, Device, Prescription, DeviceTelemetry, drift alerts) and Flink use cases (compliance alerting, device health), see the main [README](../README.md).
