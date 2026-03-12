# Demo Backend

FastAPI service that provides:

- **REST API**: `GET /patients`, `GET /devices`, `GET /prescriptions` (demo data aligned with simulation)
- **Simulation**: `GET /simulation/status`, `POST /simulation/start`, `POST /simulation/stop`
- **Telemetry stream**: `GET /telemetry/stream` (SSE)

Runs on port 8000. Requires Confluent Cloud Kafka and Schema Registry for the simulation; the REST endpoints work without them.

## Setup

```bash
cp .env.example .env
# edit .env with Kafka and Schema Registry credentials
uv sync
uv run uvicorn backend.main:app --reload --host 0.0.0.0 --port 8000
```

## Docker

From repo root: `docker compose up -d backend` (see root README).
