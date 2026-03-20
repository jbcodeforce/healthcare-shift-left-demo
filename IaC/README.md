# Confluent Cloud Terraform (Environment, Kafka, Flink, Statements)

This folder contains Terraform definitions for the healthcare-shift-left-demo Confluent Cloud setup: **environment**, **Kafka cluster**, **Flink compute pool**, and **Flink SQL statements**. You can either create all resources or attach to an existing environment and/or Kafka cluster using variables.

## Resources

| Resource            | Created ...                          |
|---------------------|----------------------------------------|
| Confluent Environment | When `environment_id` is not set     |
| Kafka Cluster       | When `kafka_cluster_id` is not set    |
| Flink Compute Pool  | Always (in the target environment)   |
| Flink SQL Statements | When `deploy_flink_statements` is true  |

## File structure

```
├── main.tf                    # Provider and data sources
├── variables.tf               # Variable definitions
├── terraform.tfvars.example  # Example variable values
├── env.tf                     # Environment (create or use existing)
├── kafka.tf                   # Kafka cluster (create or use existing)
├── flink.tf                   # Flink compute pool
├── flink-statements.tf        # Flink SQL statement deployment (DDL/DML)
├── outputs.tf                 # Output values
└── README.md                  # This file
```

## Prerequisites

1. **Confluent Cloud account** with API access.
2. **Cloud API key and secret** with permissions to create environments, clusters, and Flink compute pools (e.g. OrganizationAdmin, or EnvironmentAdmin + CloudClusterAdmin for the create path).


## Credentials from `backend/.env`

Reuse the same [`backend/.env`](../backend/.env) file which sets environment variables for the backend, to define environment variables for Terraform: `TF_VAR_*`. Run the following commands from the **repository root**:

```sh
source ./set_env_var && source ./export_terraform_env.sh
cd IaC && terraform plan
```

[`export_terraform_env.sh`](../export_terraform_env.sh) maps `.env` variable names to Terraform inputs (see the Terraform block at the top of [`backend/.env.example`](../backend/.env.example)). If `CONFLUENT_CLOUD_API_KEY` is not already set, the script sources [`set_env_var`](../set_env_var) first (which loads `backend/.env` using a path relative to the script, not your current directory).

Alternatively, `source ./set_j9r_env_sl` loads `backend/.env`, sets shift_left-related exports, and runs the same Terraform mapping.

`terraform.tfvars` (and `-var` flags) still override or supplement any variable you define there. Empty values in `.env` are not exported as `TF_VAR_*`, so Terraform keeps its defaults for optional variables.

[`main.tf`](main.tf) sets Kafka, Schema Registry, Flink, and Tableflow provider arguments to empty strings so variables such as `FLINK_API_KEY` or `KAFKA_API_KEY` in your shell (from `source`ing `.env`) do not partially configure the Confluent provider, which would trigger its “all or none” validation.

3. **Flink API key and secret** (optional, required for Flink statement deployment):
   - Create a service account with EnvironmentAdmin permissions
   - Generate API keys for this service account
   - Note the service account ID (sa-xxxxx)
4. Set credentials (do not commit `terraform.tfvars`):

   ```sh
   # Cloud API credentials (required)
   export TF_VAR_confluent_cloud_api_key="<your-cloud-api-key>"
   export TF_VAR_confluent_cloud_api_secret="<your-cloud-api-secret>"

   # Flink API credentials (required for statement deployment)
   export TF_VAR_flink_api_key="<your-flink-api-key>"
   export TF_VAR_flink_api_secret="<your-flink-api-secret>"
   export TF_VAR_flink_principal_id="<service-account-id>"
   ```

   Or copy `terraform.tfvars.example` to `terraform.tfvars` and set all credentials there.


## Create (provision all or attach to existing)

From this directory:

```sh
terraform init
terraform plan
terraform apply
```

- **Default (no variables set):** Creates a new environment, Kafka cluster (standard, single zone), and a Flink compute pool.
- **Use existing environment:** Set `environment_id = "env-xxxxx"` in `terraform.tfvars` or via `-var`. Terraform will create only the Kafka cluster (if not existing) and the Flink compute pool in that environment.
- **Use existing environment and Kafka:** Set both `environment_id` and `kafka_cluster_id`. Terraform will create only the Flink compute pool. **When using `kafka_cluster_id`, `environment_id` must also be set** (the cluster belongs to that environment).

Example with existing resources:

```sh
terraform apply -var='environment_id=env-xxxxx' -var='kafka_cluster_id=lkc-xxxxx'
```

## Clean (destroy managed resources)

```sh
terraform destroy
```

- If you **created** the environment and Kafka cluster with this Terraform, they will be destroyed along with the Flink compute pool and statements.
- If you **used existing** environment and/or Kafka cluster (via variables), only the Flink compute pool, statements, and any other resources this configuration created are destroyed; the existing environment and cluster are not modified.

## Flink Statement Deployment

This Terraform configuration automatically deploys all Flink SQL statements defined in `../pipelines/inventory.json`.

### Deployment Phases

Statements are deployed in dependency order:

1. **Phase 1: Raw DDL** - Create raw layer tables (hc_raw_patients, hc_raw_devices, hc_raw_prescriptions, hc_device_metrics)
2. **Phase 2: RMD DDL** - Create RMD layer tables (hc_src_patients, hc_src_devices, hc_src_prescriptions, dim_patients)
3. **Phase 3: Raw DML** - Start raw layer transformations (INSERT INTO statements)
4. **Phase 4: RMD DML** - Start RMD layer transformations (INSERT INTO statements)

### Statement Properties

- **DML properties files** (`.properties`): Table-specific Flink session properties are loaded from `.properties` files if they exist alongside the DML SQL files.
- **Base properties**: All statements use `sql.current-catalog` and `sql.current-database` set to the environment and cluster display names.

### Managing Statements

To skip statement deployment (deploy only infrastructure):

```sh
terraform apply -var='deploy_flink_statements=false'
```

To deploy only statements (after infrastructure exists):

```sh
terraform apply -target=confluent_flink_statement.ddl_raw -target=confluent_flink_statement.ddl_rmd -target=confluent_flink_statement.dml_raw -target=confluent_flink_statement.dml_rmd
```

### Adding New Tables

1. Add SQL files: Create `ddl.<table>.sql` and `dml.<table>.sql` (optional) in `pipelines/<layer>/<table>/sql-scripts/`
2. Update inventory: Add table entry to `pipelines/inventory.json`
3. Apply: Run `terraform apply` to deploy the new statements

The system automatically detects new tables from `inventory.json` and deploys them in the correct order based on their `product_name` (category).

## Outputs

After apply:

```sh
terraform output
```

Useful outputs:
- Infrastructure: `env_id`, `kafka_cluster_id`, `kafka_bootstrap_endpoint`, `kafka_rest_endpoint`
- Flink: `flink_compute_pool_id`, `flink_rest_endpoint`
- Statements: `flink_statements_ddl_raw`, `flink_statements_ddl_rmd`, `flink_statements_dml_raw`, `flink_statements_dml_rmd`

## Variables summary

| Variable                      | Required | Description |
|------------------------------|----------|-------------|
| `confluent_cloud_api_key`    | Yes      | Confluent Cloud API key |
| `confluent_cloud_api_secret` | Yes      | Confluent Cloud API secret |
| `flink_api_key`              | Yes*     | Flink API key (required for statement deployment) |
| `flink_api_secret`           | Yes*     | Flink API secret (required for statement deployment) |
| `flink_principal_id`         | Yes*     | Service account ID owning the Flink API key |
| `environment_id`             | No       | Existing environment ID; when set, no environment is created |
| `kafka_cluster_id`           | No       | Existing Kafka cluster ID; when set, no cluster is created (requires `environment_id`) |
| `cloud_provider`             | No       | e.g. `AWS` (default) |
| `cloud_region`               | No       | e.g. `us-east-1` (default) |
| `prefix`                     | No       | Prefix for created resource names (default `healthcare-demo`) |
| `flink_compute_pool_name`    | No       | Flink pool display name (default `healthcare-demo-pool`) |
| `flink_compute_pool_max_cfu` | No       | Max CFU for the pool (default `5`) |
| `deploy_flink_statements`    | No       | Deploy Flink SQL statements (default `true`) |
| `statement_name_prefix`      | No       | Prefix for statement names (default `hc-demo`) |

*Required only if `deploy_flink_statements` is `true` (default)
