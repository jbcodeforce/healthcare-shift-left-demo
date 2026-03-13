# Kafka Connect and Debezium connector

This folder contains the **Debezium PostgreSQL connector** configuration and the script to register it with Kafka Connect. The **Connect worker** itself (Kafka, Schema Registry, converters) is configured via **environment variables in `docker-compose.yml`**; the **connector** (which database and table to stream) is configured here and also reads from the same **`backend/.env`**.

## Where each config lives

| What | Where | Env vars (from `backend/.env`) |
|------|--------|--------------------------------|
| **Connect worker** (Kafka bootstrap, Schema Registry, Avro auth, subject prefix, REST port) | `docker-compose.yml` → `kafka-connect` service | `KAFKA_BOOTSTRAP_SERVERS`, `KAFKA_SASL_USERNAME`, `KAFKA_SASL_PASSWORD`, `SCHEMA_REGISTRY_URL`, `SCHEMA_REGISTRY_BASIC_AUTH_USER_INFO`, `SCHEMA_SUBJECT_PREFIX` (converter-level, same as producer) |
| **Connector** (Postgres host, DB, user, password, topic prefix, table) | `debezium-postgres.json` + `register-connector.sh` | `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_HOST`, `POSTGRES_PORT`, `POSTGRES_DB`, `DEBEZIUM_TOPIC_PREFIX`, `TABLE_INCLUDE_LIST`, `CONNECT_URL`, `DEBEZIUM_CONNECTOR_NAME` |

The worker env vars are **not** in this folder because they are applied when the Connect container starts (Compose). The connector config is sent to the Connect REST API by `register-connector.sh`, which sources `backend/.env` and substitutes the same variables into `debezium-postgres.json`.

## Files

- **`debezium-postgres.json`** — Connector config template. Placeholders are replaced by `register-connector.sh` from env (defaults in the script).
- **`register-connector.sh`** — Waits for Connect, then creates or updates the connector using the JSON (with env substitution). Run from repo root: `./connect/register-connector.sh`. Optionally set `CONNECT_URL` if Connect is not on port 8083.
- **`create-topics.sh`** — Creates the Debezium data topic (e.g. `healthcare.public.prescriptions`) via Confluent Cloud CLI to avoid `UNKNOWN_TOPIC_OR_PARTITION`. Run from repo root; requires `ccloud`.
- **`connect-distributed.properties.example`** — Reference worker config (key/converter, security). The running worker is configured via Compose env, not this file.
- **`Dockerfile`** — Builds the Connect image (Confluent + Debezium PostgreSQL plugin + custom subject strategy JAR + entrypoint).
- **`subject-strategy/`** — Maven project for **PrefixTopicNameStrategy**: subject names `:{prefix}:{topic}-key` / `-value` to align with the backend producer. The JAR is built in the Docker image and copied to `/etc/kafka-connect/jars/`, which the Connect launch script adds to the worker’s main CLASSPATH so the Avro converter can load the strategy class.

## Environment variables used by the connector (register-connector.sh + JSON)

All are optional; defaults are in the script. Source: `backend/.env` (script sources it when present).

| Variable | Default | Description |
|----------|---------|-------------|
| `CONNECT_URL` | `http://localhost:8083` | Kafka Connect REST API base URL. |
| `DEBEZIUM_CONNECTOR_NAME` | `debezium-postgres-healthcare` | Connector name. |
| `POSTGRES_HOST` | `postgres` | Postgres host (use `postgres` when Connect runs in same Compose network). |
| `POSTGRES_PORT` | `5432` | Postgres port. |
| `POSTGRES_DB` | `healthcare` | Database name. |
| `POSTGRES_USER` | `demo` | Database user (for logical replication). |
| `POSTGRES_PASSWORD` | `demo` | Database password. |
| `DEBEZIUM_TOPIC_PREFIX` | `healthcare` | Topic prefix for CDC topics (e.g. `healthcare.public.prescriptions`). |
| `TABLE_INCLUDE_LIST` | `public.prescriptions` | Table(s) to capture (Debezium format). |
| `DEBEZIUM_SLOT_NAME` | `debezium_healthcare_slot` | Replication slot name (unique per connector). |

To override, set in `backend/.env` or export before running `./connect/register-connector.sh`.

### Publication and table (required for connector to run)

The connector uses the **existing publication** `debezium_healthcare` and does not create it (PostgreSQL allows only superusers to create publications). The Postgres init script `postgres/init.d/02-debezium-replication.sh` creates this publication for `public.prescriptions`. The table is created in `postgres/init.d/01-prescriptions-schema.sql`. If you already had a Postgres volume before these scripts existed, create the publication manually:

```bash
docker exec -it postgres psql -U demo -d healthcare -c "CREATE PUBLICATION IF NOT EXISTS debezium_healthcare FOR TABLE public.prescriptions;"
```

If the table does not exist yet, the backend creates it on first run (it uses `CREATE TABLE IF NOT EXISTS`).

### Schema subject prefix

The backend producer (see `backend/src/backend/producer.py`) registers schemas with subject names like `:{prefix}:{topic}-key` and `:{prefix}:{topic}-value` using `schema_subject_prefix` (e.g. `.flink-dev`). Connect uses the same format so that Debezium-registered schemas live under the same “context” in Schema Registry. The Connect image includes a custom **PrefixTopicNameStrategy** (built from `connect/subject-strategy/`). In `docker-compose.yml`, the worker is configured with:

- `CONNECT_*_KEY_SUBJECT_NAME_STRATEGY` / `CONNECT_*_VALUE_SUBJECT_NAME_STRATEGY` = `io.confluent.kafka.serializers.subject.PrefixTopicNameStrategy`
- `CONNECT_*_SUBJECT_NAME_PREFIX` = `SCHEMA_SUBJECT_PREFIX` from `backend/.env` (default `.flink-dev`)

Set `SCHEMA_SUBJECT_PREFIX` in `backend/.env` to match the backend’s `schema_subject_prefix` (or leave unset to use the default).


### Topic pre-creation (Confluent Cloud)

Debezium writes to topics named `{topic.prefix}.{schema}.{table}`. With default `DEBEZIUM_TOPIC_PREFIX=healthcare` and `TABLE_INCLUDE_LIST=public.prescriptions`, the data topic is **`healthcare.public.prescriptions`**. The connector also uses a **database history** topic (e.g. `dbz_healthcare` or similar, depending on the connector).

If you see `UNKNOWN_TOPIC_OR_PARTITION` in the Connect logs, create the topic before starting (or restarting) the connector. Example with Confluent Cloud CLI:

```bash
# Data topic (partition count is your choice; 1 is fine for low volume)
ccloud kafka topic create healthcare.public.prescriptions --partitions 1
```

You can also create the topic in the Confluent Cloud UI. Or run `./connect/create-topics.sh` (requires `ccloud`). After the topic exists, the connector should proceed without that warning.

### Connector not streaming / no schemas in Schema Registry

If the connector stays in FAILED or does not produce events or register schemas:

1. **Publication** — The connector is configured with `publication.name=debezium_healthcare`. That publication must exist and include `public.prescriptions`. See “Publication and table” above. Check: `docker exec -it postgres psql -U demo -d healthcare -c "\dRp"`.

2. **Connector status and logs** — `curl -s http://localhost:8083/connectors/debezium-postgres-healthcare/status | jq .` and `docker logs kafka-connect`. Look for permission errors, Schema Registry 401, or “publication does not exist”.

3. **Schema Registry auth** — Ensure `SCHEMA_REGISTRY_BASIC_AUTH_USER_INFO` in `backend/.env` is the Schema Registry API key and secret (e.g. `key:secret`). Restart Connect after changing: `docker compose --env-file backend/.env up -d kafka-connect --force-recreate`.

4. **Topic exists** — Create `healthcare.public.prescriptions` if you see `UNKNOWN_TOPIC_OR_PARTITION` (see “Topic pre-creation” above).

5. **Fresh start (new volume)** — To re-run Postgres init (table + publication), remove the volume and start again: `docker compose down -v && docker compose up -d postgres`, then start backend and Connect and register the connector.
