# Flink Statements Terraform Implementation Summary

Attention: This is not recommended for Production deployment!

## What Was Implemented

This demonstration adds automated Flink SQL statement deployment to the existing Terraform infrastructure. The system automatically deploys all DDL and DML statements defined in `pipelines/inventory.json`.

## Files Created/Modified

### New Files
- **`flink-statements.tf`** - Main statement deployment logic with 4 phases (DDL raw, DDL rmd, DML raw, DML rmd)
- **`IMPLEMENTATION_SUMMARY.md`** - This file

### Modified Files
- **`variables.tf`** - Statement deployment options (Flink app keys are Terraform-managed; see `app_credentials.tf`)
- **`main.tf`** - Added Flink provider configuration and environment data source
- **`env.tf`** - Updated to expose environment display name for both created and existing environments
- **`outputs.tf`** - Added statement deployment outputs
- **`README.md`** - Comprehensive documentation updates
- **`terraform.tfvars.example`** - Notes on Terraform-managed API keys
- **`app_credentials.tf`** - Demo service account, RBAC, Kafka/SR/Flink API keys (as applicable in current repo)

## Architecture

### Deployment Phases

The implementation deploys statements in 4 sequential phases to ensure dependencies are met:

1. **Phase 1: Raw DDL** - Creates raw layer tables
   - `hc_raw_patients`
   - `hc_raw_devices`
   - `hc_raw_prescriptions`
   - `hc_device_metrics`

2. **Phase 2: RMD DDL** - Creates RMD/dimension tables
   - `hc_src_patients`
   - `hc_src_devices`
   - `hc_src_prescriptions`
   - `dim_patients`

3. **Phase 3: Raw DML** - Starts raw layer transformations
   - INSERT INTO statements for raw tables with DML

4. **Phase 4: RMD DML** - Starts RMD layer transformations
   - INSERT INTO statements for RMD/dimension tables with DML

### Key Features

- **Inventory-driven**: Reads table definitions from `pipelines/inventory.json`
- **Automatic dependency ordering**: Uses Terraform `depends_on` to ensure correct deployment order
- **Properties file support**: Loads Flink session properties from `.properties` files when available
- **Flexible deployment**: Can skip statement deployment with `deploy_flink_statements=false`
- **Terraform-managed credentials**: Demo service account and Kafka / Schema Registry / Flink API keys (`app_credentials.tf`); use `terraform output backend_env_snippet` for `backend/.env`

## Required Variables

Add these to your `terraform.tfvars`:

```hcl
# Confluent Cloud API credentials (existing)
confluent_cloud_api_key    = "YOUR_CLOUD_API_KEY"
confluent_cloud_api_secret = "YOUR_CLOUD_API_SECRET"

# Flink statement deployment (optional; app API keys are created by Terraform)
# deploy_flink_statements = true
# statement_name_prefix   = "hc-demo"

# After apply, populate backend/.env from outputs:
#   terraform output -raw backend_env_snippet
```

## How to Use

### Initial Deployment

```bash
cd IaC
terraform init
terraform plan
terraform apply
```

This will:
1. Create/use environment and Kafka cluster (as before)
2. Create Flink compute pool (as before)
3. **NEW**: Deploy all Flink SQL statements in dependency order

### Deploy Only Infrastructure (Skip Statements)

```bash
terraform apply -var='deploy_flink_statements=false'
```

### Deploy/Update Only Statements

```bash
terraform apply \
  -target=confluent_flink_statement.ddl_raw \
  -target=confluent_flink_statement.ddl_rmd \
  -target=confluent_flink_statement.dml_raw \
  -target=confluent_flink_statement.dml_rmd
```

## Adding New Tables

1. **Create SQL files** in appropriate directory:
   ```
   pipelines/<layer>/<table_name>/sql-scripts/
   ├── ddl.<table_name>.sql          # Required
   ├── dml.<table_name>.sql          # Optional
   └── dml.<table_name>.properties   # Optional
   ```

2. **Update inventory.json**:
   ```json
   {
     "table_name": "your_table_name",
     "product_name": "raw or rmd",
     "type": "unknown-type",
     "dml_ref": "pipelines/<layer>/<table>/sql-scripts/dml.<table>.sql",
     "ddl_ref": "pipelines/<layer>/<table>/sql-scripts/ddl.<table>.sql",
     "table_folder_name": "pipelines/<layer>/<table>"
   }
   ```

3. **Run terraform apply**:
   ```bash
   terraform apply
   ```

The new statements will be automatically deployed in the correct order.

## Outputs

After deployment, check statement status:

```bash
terraform output flink_statements_ddl_raw
terraform output flink_statements_ddl_rmd
terraform output flink_statements_dml_raw
terraform output flink_statements_dml_rmd
```

## Implementation Details

### Inventory.json Structure

Each table entry requires:
- `table_name`: Flink table name
- `product_name`: Category for deployment ordering (raw/rmd)
- `ddl_ref`: Path to DDL SQL file
- `dml_ref`: Path to DML SQL file (optional, empty string if no DML)

### Properties File Handling

If a table has a DML statement, the system automatically looks for a corresponding `.properties` file:
- DML file: `dml.<table>.sql`
- Properties file: `dml.<table>.properties` (same directory)

Properties format (one per line):
```properties
sql.tables.scan.idle-timeout=1s
# Comments start with #
```

If no properties file exists, only base properties are used:
- `sql.current-catalog` = environment display name
- `sql.current-database` = Kafka cluster display name

### Error Handling

- Missing SQL files: Terraform will fail with clear error message
- Missing properties files: Gracefully handled, base properties used
- Dependency conflicts: Prevented by phase-based deployment order

## Testing

Before applying to production:

1. **Validate syntax**: `terraform validate`
2. **Preview changes**: `terraform plan`
3. **Test with single table**: Comment out tables in inventory.json
4. **Verify statements**: Check Confluent Cloud UI after apply

## Troubleshooting

### Statement fails to deploy
- Check SQL syntax in the .sql file
- Verify referenced tables exist (check dependency order)
- Review Flink compute pool logs in Confluent Cloud UI

### Properties not applied
- Verify .properties file exists in same directory as .sql file
- Check property syntax (key=value, one per line)
- Confirm file is named correctly: `dml.<table>.properties`

### Permission errors
- Verify service account has EnvironmentAdmin role
- Check API key belongs to the correct service account
- Confirm `terraform output app_service_account_id` matches `PRINCIPAL_ID` in `backend_env` / statements principal

## Next Steps

1. Set Flink API credentials in `terraform.tfvars`
2. Run `terraform plan` to preview statement deployment
3. Run `terraform apply` to deploy statements
4. Monitor statement execution in Confluent Cloud UI
5. Verify data flowing through pipelines

## References

- Implementation based on: `flink-studies/e2e-demos/cc-cdc-tx-demo/cccloud/cc-flink-sql/terraform/`
- Confluent Flink Statement docs: https://registry.terraform.io/providers/confluentinc/confluent/latest/docs/resources/confluent_flink_statement
