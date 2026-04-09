# Healthcare Shift-Left Demo - Flink Pipelines (dbt)

End-to-end flow: **inventory → generated dbt models → `dbt compile` → manifest → Confluent Flink REST API**.

## How it works

1. **`pipelines/inventory.json`** lists each table’s DDL/DML paths under `pipelines/raw` and `pipelines/rmd`.
2. **`generate_flink_models.py`** copies that SQL into ephemeral dbt models under `models/flink/{raw,rmd}/` (with `meta.deploy_sequence` for order).
3. **`dbt compile`** produces `target/manifest.json` with **`compiled_code`** for each model (Flink SQL, not executed on Postgres).
4. **`dbt_flink_deploy.py`** reads the manifest and creates/updates Flink statements in order.

## Prerequisites

```bash
pip install -r requirements.txt   # or repo root requirements.txt
source ../../backend/.env         # Confluent keys, ENV_ID, ORG_ID / FLINK_ORG_ID, Flink pool, etc.
```

## When `inventory.json` changes

```bash
cd pipelines/flink_pipelines
python3 generate_flink_models.py
```

Commit the updated files under `models/flink/`.

## Deploy (full dbt pipeline)

```bash
cd pipelines/flink_pipelines
source ../../backend/.env
python3 dbt_flink_deploy.py --all
python3 dbt_flink_deploy.py --layer rmd
python3 dbt_flink_deploy.py --table hc_raw_patients
```

- **`--skip-dbt-compile`** — reuse existing `target/manifest.json` (no `dbt compile`).
- **`--legacy-inventory`** — skip dbt; read SQL only from `inventory.json` (same as `deploy_flink.py`).

## Other CLIs

```bash
python3 deploy_flink.py --all              # inventory paths only, no dbt
dbt compile --project-dir . --profiles-dir .
dbt ls
dbt docs generate && dbt docs serve
```

`dbt run-operation deploy_flink_pipelines` prints the recommended shell commands (macros cannot call HTTP).

## See also

- [DBT deployment guide](../DBT_DEPLOYMENT_GUIDE.md)
- [IaC / Terraform](../../IaC/README.md)
