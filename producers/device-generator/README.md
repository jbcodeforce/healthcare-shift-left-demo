# Device Generator

FastAPI app to drive **device telemetry simulation** that produces records to **Confluent Cloud Kafka** in **Avro**, matching the `device-metrics` Flink table schema.

## APIs

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Liveness |
| GET | `/simulation/status` | Whether simulation is running |
| POST | `/simulation/start` | Start device simulation (body: optional `patient_id`, `simulation_type`: `all` \| `single`) |
| POST | `/simulation/stop` | Stop device simulation |
| GET | `/telemetry/stream` | **SSE** stream of telemetry (for dashboards) |

## Setup

- **Python**: `uv` recommended.

```bash
cd device-generator
uv sync
```

## Configuration

Set environment variables (or use a `.env` file in this directory):

**Kafka (Confluent Cloud)**

- `KAFKA_BOOTSTRAP_SERVERS` – cluster bootstrap (e.g. `pkc-xxx.us-east-1.aws.confluent.cloud:9092`)
- `KAFKA_SASL_USERNAME` – cluster API key
- `KAFKA_SASL_PASSWORD` – cluster API secret
- `KAFKA_TOPIC` – topic name (default: `device_metrics`)

**Schema Registry (Confluent Cloud)**

- `SCHEMA_REGISTRY_URL` – Schema Registry endpoint (e.g. `https://psrc-xxx.us-east-1.aws.confluent.cloud`)
- `SCHEMA_REGISTRY_BASIC_AUTH_USER_INFO` – `key:secret` for Schema Registry

**Simulation**

- `SIMULATION_INTERVAL_SECONDS` – seconds between batches (default: `2.0`)
- `SIMULATION_NUM_PATIENTS` – number of patients/devices (default: `5`)

See `.env.example` for a template.

## Tests

Install dev dependencies and run tests **from this directory** using the project venv so that `device_generator` and its dependencies (e.g. `pydantic_settings`) are available:

```bash
cd producers/device-generator
uv sync --extra dev
uv run pytest tests/ -v
```

If you see `ModuleNotFoundError: No module named 'pydantic_settings'`, run pytest via **`uv run pytest`** (not bare `pytest`) from `producers/device-generator` after `uv sync --extra dev`.

**Integration tests** (in `tests/integration/`) send one record to Kafka and exercise start/stop simulation. They are skipped unless `KAFKA_BOOTSTRAP_SERVERS` (and Confluent credentials) are set—e.g. by using a `.env` file in this directory:

```bash
# With .env present (Confluent Cloud credentials)
uv run pytest tests/integration/ -v
```

## Run

### Local (uv)

```bash
uv run uvicorn device_generator.main:app --host 0.0.0.0 --port 8000
# or
uv run device-generator
```

### Docker (microservice)

From the **repo root** (`healthcare-shift-left-demo/`):

```bash
cp producers/device-generator/.env.example producers/device-generator/.env
# edit producers/device-generator/.env with your Confluent Cloud credentials

docker compose up -d device-generator
```

API: `http://localhost:8000`. Rebuild after code changes: `docker compose up -d --build device-generator`.

Then:

- Start simulation: `curl -X POST http://localhost:8000/simulation/start`
- Status: `curl http://localhost:8000/simulation/status`
- Stop: `curl -X POST http://localhost:8000/simulation/stop`

### SSE for dashboards

Connect to the telemetry stream with `GET /telemetry/stream` (Server-Sent Events). Each event is either:

- **`telemetry`**: one JSON object per record: `device_id`, `patient_id`, `ts`, `metric_name`, `metric_value`, `software_version`.
- **`ping`**: sent every ~15s when idle to keep the connection alive.

Example in the browser:

```js
const es = new EventSource("http://localhost:8000/telemetry/stream");
es.addEventListener("telemetry", (e) => {
  const rec = JSON.parse(e.data);
  console.log(rec); // use for charts, tables, etc.
});
```

Start the simulation (e.g. `POST /simulation/start`) to see events. Multiple dashboard clients can subscribe to the same stream.

## Schema

Produced records match the `device-metrics` table:

- `device_id`, `patient_id`, `ts` (epoch ms), `metric_name`, `metric_value`, `software_version`

One device per patient; three metrics per device per tick: **Pressure**, **FlowRate**, **MotorSpeed**. Values are slightly randomized around base values for testing.
