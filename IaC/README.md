# Confluent Cloud Terraform (Environment, Kafka, Flink, Statements)

This folder contains Terraform definitions for the healthcare-shift-left-demo Confluent Cloud setup: **environment**, **Kafka cluster**, **Schema Registry** (Essentials, data source), **Flink compute pool**, **Terraform-managed API keys** for the demo app, and optional **Flink SQL statements**. You can either create all resources or attach to an existing environment and/or Kafka cluster using variables.

## Resources

| Resource            | Created ...                          |
|---------------------|----------------------------------------|
| Confluent Environment | When `environment_id` is not set     |
| Kafka Cluster       | When `kafka_cluster_id` is not set    |
| Service Account     | When `service_account_id` is not set  |
| Flink Compute Pool  | When `flink_compute_pool_id` is not set |
| Demo app API keys   | Always (Kafka, Schema Registry, Flink; see `app_credentials.tf`) |
| Flink SQL Statements | When `deploy_flink_statements` is true  |
| **Tableflow & S3**  | **When `enable_tableflow` is true (see [Tableflow Setup Guide](TABLEFLOW_SETUP_GUIDE.md))** |

## File structure

```
├── main.tf                    # Provider and data sources
├── variables.tf               # Variable definitions
├── terraform.tfvars.example  # Example variable values
├── env.tf                     # Environment (create or use existing)
├── kafka.tf                   # Kafka cluster (create or use existing)
├── schema_registry.tf         # Schema Registry data source
├── app_credentials.tf         # Service account, RBAC, Kafka/SR/Flink API keys
├── flink.tf                   # Flink compute pool
├── flink-statements.tf        # Flink SQL statement deployment (DDL/DML)
├── tableflow.tf               # Tableflow connections and S3 sinks (NEW!)
├── outputs.tf                 # Output values
├── README.md                  # This file
├── TABLEFLOW_SETUP_GUIDE.md   # Tableflow setup documentation
└── validate_tableflow.sh      # Validation script for Tableflow
```

## Prerequisites

1. **Confluent Cloud account** with API access.
2. **Cloud API key and secret** with permissions to create environments, clusters, service accounts, role bindings, API keys, and Flink compute pools (e.g. OrganizationAdmin, or EnvironmentAdmin + appropriate roles for the create path).

## Credentials from `backend/.env`

Reuse [`backend/.env`](../backend/.env) to supply **only** Terraform variables (`TF_VAR_*`) such as `confluent_cloud_api_key` / `confluent_cloud_api_secret`, `cloud_provider`, `environment_id`, etc. From the **repository root**:

```sh
source ./set_env_var && source ./export_terraform_env.sh
cd IaC && terraform plan
```

[`export_terraform_env.sh`](../export_terraform_env.sh) maps `.env` names to Terraform inputs (see [`backend/.env.example`](../backend/.env.example)). It does **not** set removed variables for Flink keys; those come from Terraform outputs after apply.

[`main.tf`](main.tf) sets Kafka, Schema Registry, Flink, and Tableflow provider arguments to empty strings so shell variables such as `FLINK_API_KEY` or `KAFKA_API_KEY` from `.env` do not partially configure the Confluent provider (“all or none” validation).

### Cloud API credentials for Terraform

Do not commit `terraform.tfvars` (may contain secrets):

```sh
export TF_VAR_confluent_cloud_api_key="<your-cloud-api-key>"
export TF_VAR_confluent_cloud_api_secret="<your-cloud-api-secret>"
```

Or copy `terraform.tfvars.example` to `terraform.tfvars` and set values there.

### After apply: backend Kafka / SR / Flink keys

Terraform creates a **demo app service account** and **three API keys** (Kafka, Schema Registry, Flink). Key **secrets** are stored in Terraform state; treat state as confidential.

```sh
cd IaC
terraform output -raw backend_env_snippet >> ../backend/.env.local   # example: merge into a new file first
# Or inspect structured map:
terraform output -json backend_env
```

Individual outputs: `app_service_account_id`, `app_kafka_api_key_id`, `app_kafka_api_key_secret`, `app_schema_registry_api_key_id`, `app_schema_registry_api_key_secret`, `app_flink_api_key_id`, `app_flink_api_key_secret`.

To **merge** the `backend_env` map into an existing [`backend/.env`](../backend/.env) (update only keys that differ or are missing; skip the write if nothing changed), from the repo root:

```sh
./scripts/update_backend_env_from_terraform.sh
# Preview: ./scripts/update_backend_env_from_terraform.sh --dry-run
```

If an apply fails on **RBAC** (role or CRN), adjust `confluent_role_binding` resources in [`app_credentials.tf`](app_credentials.tf) per [Confluent predefined RBAC roles](https://docs.confluent.io/cloud/current/security/access-control/rbac/predefined-rbac-roles.html). **`DataSteward`** for Schema Registry must use the **environment** `resource_name` (`local.environment_resource_name`), not the Schema Registry cluster CRN—Confluent rejects `DataSteward` / `ResourceOwner` on `SchemaRegistry` cluster scope.

## Create (provision all or attach to existing)

From this directory:

```sh
terraform init
terraform plan
terraform apply
```

- **Default (no variables set):** Creates a new environment, Kafka cluster (standard, single zone), service account, Flink compute pool, and demo app API keys.
- **Use existing environment:** Set `environment_id = "env-xxxxx"` in `terraform.tfvars` or via `-var`. Terraform will create the Kafka cluster (if not existing), service account, Flink pool, and keys in that environment.
- **Use existing environment and Kafka:** Set both `environment_id` and `kafka_cluster_id`. Terraform will create the service account, Flink compute pool, and demo app keys. **When using `kafka_cluster_id`, `environment_id` must also be set** (the cluster belongs to that environment).
- **Use existing service account:** Set `service_account_id = "sa-xxxxx"`. Terraform will use the existing service account and create API keys for it. The service account must already have the necessary RBAC permissions, or Terraform will attempt to add them.
- **Use existing Flink compute pool:** Set `flink_compute_pool_id = "lfcp-xxxxx"` and `environment_id`. Terraform will use the existing Flink compute pool instead of creating a new one.
- **Attach to fully existing infrastructure:** Set `environment_id`, `kafka_cluster_id`, `service_account_id`, and `flink_compute_pool_id` to use all existing resources. Terraform will only create API keys and optionally deploy Flink statements.

Example with existing resources:

```sh
# Use existing environment and Kafka cluster only
terraform apply -var='environment_id=env-xxxxx' -var='kafka_cluster_id=lkc-xxxxx'

# Use all existing resources (SRE scenario)
terraform apply \
  -var='environment_id=env-xxxxx' \
  -var='kafka_cluster_id=lkc-xxxxx' \
  -var='service_account_id=sa-xxxxx' \
  -var='flink_compute_pool_id=lfcp-xxxxx'
```

## Clean (destroy managed resources)

```sh
terraform destroy
```

- If you **created** resources with this Terraform, they will be destroyed (environment, Kafka cluster, service account, Flink compute pool, API keys, and statements).
- If you **used existing** resources (via variables), only resources this stack created are destroyed; existing resources are not removed.
  - Existing environment → not destroyed
  - Existing Kafka cluster → not destroyed
  - Existing service account → not destroyed (but role bindings created by Terraform will be removed)
  - Existing Flink compute pool → not destroyed
  - API keys → always destroyed (they were created by Terraform)

## Flink Statement Deployment

This configuration can deploy Flink SQL statements from `../pipelines/inventory.json`. Statements use the **Terraform-managed** Flink API key and demo service account (`app_credentials.tf`).

### Deployment Phases

Statements are deployed in dependency order:

1. **Phase 1: Raw DDL** - Raw layer tables
2. **Phase 2: RMD DDL** - RMD / dimension tables
3. **Phase 3: Raw DML** - Raw layer transformations
4. **Phase 4: RMD DML** - RMD layer transformations

### Statement Properties

- **DML properties files** (`.properties`): Loaded when present next to DML SQL.
- **Base properties**: `sql.current-catalog` and `sql.current-database` use environment and Kafka cluster display names.

### Managing Statements

To skip statement deployment (infrastructure and keys only):

```sh
terraform apply -var='deploy_flink_statements=false'
```

To deploy only statements (after infrastructure exists):

```sh
terraform apply -target=confluent_flink_statement.ddl_raw -target=confluent_flink_statement.ddl_rmd -target=confluent_flink_statement.dml_raw -target=confluent_flink_statement.dml_rmd
```

### Adding New Tables

1. Add SQL under `pipelines/<layer>/<table>/sql-scripts/`
2. Update `pipelines/inventory.json`
3. Run `terraform apply`

## Outputs

```sh
terraform output
```

Useful outputs:

- Infrastructure: `env_id`, `kafka_cluster_id`, `kafka_bootstrap_endpoint`, `kafka_rest_endpoint`
- Schema Registry: `schema_registry_id`, `schema_registry_endpoint`
- Flink: `flink_compute_pool_id`, `flink_rest_endpoint`
- Demo credentials: `app_service_account_id`, `app_*_api_key_*`, `backend_env`, `backend_env_snippet` (sensitive)
- Statements (when enabled): `flink_statements_ddl_raw`, `flink_statements_ddl_rmd`, `flink_statements_dml_raw`, `flink_statements_dml_rmd`

## Variables summary

| Variable                      | Required | Description |
|------------------------------|----------|-------------|
| `confluent_cloud_api_key`    | Yes      | Confluent Cloud API key |
| `confluent_cloud_api_secret` | Yes      | Confluent Cloud API secret |
| `environment_id`             | No       | Existing environment ID; when set, no environment is created |
| `kafka_cluster_id`           | No       | Existing Kafka cluster ID; when set, no cluster is created (requires `environment_id`) |
| `service_account_id`         | No       | Existing service account ID; when set, no service account is created (API keys still created) |
| `flink_compute_pool_id`      | No       | Existing Flink compute pool ID; when set, no pool is created (requires `environment_id`) |
| `cloud_provider`             | No       | e.g. `AWS` (default) |
| `cloud_region`               | No       | e.g. `us-west-2` (default) |
| `prefix`                     | No       | Prefix for resource names (default `health`) |
| `flink_compute_pool_name`    | No       | Flink pool display name |
| `flink_compute_pool_max_cfu` | No       | Max CFU for the pool (default `5`) |
| `deploy_flink_statements`    | No       | Deploy Flink SQL statements (default `false`) |
| `statement_name_prefix`      | No       | Prefix for statement names (default `hc`) |
| **`enable_tableflow`**       | **No**   | **Enable Tableflow to write Flink data to S3 (default `false`)** |
| **`confluent_external_id`**  | **No**   | **External ID for Tableflow IAM role (required when `enable_tableflow=true`)** |
| **`confluent_aws_account_id`** | **No** | **Confluent AWS account ID for Tableflow (default `761327592718`)** |

Kafka, Schema Registry, and Flink **application** API keys are not variables; they are created in [`app_credentials.tf`](app_credentials.tf) and exposed via outputs.

## Tableflow Setup (Issue #5)

**Tableflow** writes Flink table data to S3 as Parquet or Iceberg tables, enabling real-time analytics from object storage.

### Quick Start

1. **Prerequisites**: 
   - Flink tables deployed and running
   - AWS credentials configured
   - Confluent External ID from Confluent support/UI

2. **Enable Tableflow**:
   ```hcl
   # In terraform.tfvars
   enable_tableflow = true
   confluent_external_id = "your-external-id-here"
   ```

3. **Deploy**:
   ```bash
   terraform init  # First time only (adds AWS provider)
   terraform plan
   terraform apply
   ```

4. **Verify**:
   ```bash
   ./validate_tableflow.sh
   ```

### What Gets Created

When `enable_tableflow = true`:
- ✅ S3 bucket for analytics data
- ✅ IAM role with S3 access for Confluent
- ✅ Tableflow connections (3)
- ✅ Tableflow sinks (3) writing to:
  - `s3://bucket/anomalies/` (from `hc_fct_dev_anomaly`)
  - `s3://bucket/prescription_changes/` (from `hc_fct_drift_evts`)
  - `s3://bucket/telemetries/` (from `hc_fct_telemetries`)

### Complete Guide

See **[TABLEFLOW_SETUP_GUIDE.md](TABLEFLOW_SETUP_GUIDE.md)** for:
- Step-by-step setup instructions
- Configuration details
- Troubleshooting guide
- Cost optimization tips
- Maintenance procedures

### Success Criteria (Issue #5)

- [x] S3 bucket created via Terraform
- [x] IAM role and policy configured
- [x] Tableflow enabled on all 3 fact tables
- [ ] Data flowing to S3 (verify after deployment)
- [ ] DuckDB can query S3 (test with analytics dashboard)
