# Sample Parquet tables for S3 analytics validation

This folder contains scripts and pre-generated Parquet tables you can upload to S3 to validate the DuckDB-backed analytics API and dashboard.

## Table schemas

| Table | Columns | Purpose |
|-------|---------|---------|
| **anomalies** | `device_id`, `ts`, `metric_name`, `severity` | One row per anomaly event; dashboard shows count per device. |
| **prescription_changes** | `device_id`, `changed_at`, `operation`, `prescription_id` | Config change history; dashboard shows changes over time. |
| **device_first_seen** | `device_id`, `first_seen_at` | When each device was first seen; dashboard shows new devices over time. |

Timestamps (`ts`, `changed_at`, `first_seen_at`) are Unix epoch milliseconds.

## Generate or regenerate sample data

From the repo root, with DuckDB available (e.g. backend dev deps):

```bash
cd backend && uv sync --extra dev && uv run python ../analytics/sample-data/generate_sample_data.py
```

Or with a global DuckDB install:

```bash
pip install duckdb
python analytics/sample-data/generate_sample_data.py
```

Output:

- **`parquet/`** — Single-file tables: `anomalies.parquet`, `prescription_changes.parquet`, `device_first_seen.parquet`. Use these for simple S3 layouts.
- **`parquet-partitioned/`** — Hive-style partitioning by `date` (e.g. `anomalies/date=2024-03-09/data_0.parquet`). Use for testing partitioned reads.

## Upload to S3

1. Create a bucket (e.g. `my-healthcare-analytics`) and choose a prefix (e.g. `demo/`).

2. Upload either the flat or partitioned folder.

   **Option A — Flat (single file per table):**

   ```bash
   aws s3 cp analytics/sample-data/parquet/ s3://MY_BUCKET/demo/parquet/ --recursive
   ```

   **Option B — Partitioned:**

   ```bash
   aws s3 cp analytics/sample-data/parquet-partitioned/ s3://MY_BUCKET/demo/parquet-partitioned/ --recursive
   ```

3. Backend will query with paths like:

   - Flat: `s3://MY_BUCKET/demo/parquet/anomalies.parquet`, `.../prescription_changes.parquet`, `.../device_first_seen.parquet`
   - Partitioned: `s3://MY_BUCKET/demo/parquet-partitioned/anomalies/`, etc. (DuckDB `read_parquet` with glob or directory path)

## Backend configuration

Set these (e.g. in `backend/.env`) so the analytics module can read from S3:

```env
ANALYTICS_S3_BUCKET=my-healthcare-analytics
ANALYTICS_S3_PREFIX=demo/parquet
# Or for partitioned: ANALYTICS_S3_PREFIX=demo/parquet-partitioned

# AWS credentials (or use IAM role / credential_chain in DuckDB)
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
AWS_REGION=us-east-1
```

The backend will build URIs like `s3://{bucket}/{prefix}/anomalies.parquet` for flat layout, or `s3://{bucket}/{prefix}/anomalies/*.parquet` (or directory) for partitioned.

## Iceberg

These samples are Parquet only. To use Iceberg tables in S3, you would create them with a catalog (e.g. Flink Iceberg connector or PyIceberg) and point DuckDB at the table metadata path, e.g. `iceberg_scan('s3://bucket/path/metadata/v1.metadata.json')`. The same logical schemas above apply.
