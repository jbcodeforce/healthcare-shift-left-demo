# -----------------------------------------------------------------------------
# Flink Statements
# All DDL and DML statements for healthcare demo tables
# Deploys tables from inventory.json: raw layer, rmd layer, and dimensions
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Local Values - Table Definitions from inventory.json
# -----------------------------------------------------------------------------
locals {
  # Load inventory.json
  inventory = jsondecode(file("${path.module}/../pipelines/inventory.json"))

  # Base properties for Flink statements
  # Use display names (not IDs) for catalog and database
  base_properties = {
    "sql.current-catalog"  = local.env_display_name
    "sql.current-database" = local.kafka_display_name
  }

  # Parse inventory.json into a map of tables with their configurations
  # Convert from inventory format to our internal format
  tables = {
    for table_name, config in local.inventory : table_name => {
      table_name       = config.table_name
      product_name     = config.product_name
      type             = config.type
      ddl_path         = "${path.module}/../${config.ddl_ref}"
      dml_path         = config.dml_ref != null && config.dml_ref != "" ? "${path.module}/../${config.dml_ref}" : null
      # Properties file is derived from DML path: replace .sql with .properties
      properties_path  = config.dml_ref != null && config.dml_ref != "" ? "${path.module}/../${replace(config.dml_ref, ".sql", ".properties")}" : null
      has_dml          = config.dml_ref != null && config.dml_ref != ""
      category         = config.product_name
    }
  }

  # Helper to parse properties files
  # Merges base properties with table-specific properties from .properties files
  parse_properties = {
    for table_name, table_config in local.tables : table_name => (
      table_config.properties_path != null && table_config.has_dml ? (
        merge(
          local.base_properties,
          {
            for line in [
              for l in split("\n", try(file(table_config.properties_path), "")) :
              trimspace(l)
              if length(trimspace(l)) > 0 && !startswith(trimspace(l), "#")
            ] :
            split("=", line)[0] => try(split("=", line)[1], "")
            if length(split("=", line)) == 2
          }
        )
      ) : local.base_properties
    )
  }

  # Deployment order by category (raw tables first, then rmd, then dimensions)
  # This ensures dependencies are met
  deployment_order = {
    "raw" = 1
    "rmd" = 2
  }

  # Filter tables by deployment phase
  raw_tables = {
    for table_name, config in local.tables :
    table_name => config
    if config.category == "raw"
  }

  rmd_tables = {
    for table_name, config in local.tables :
    table_name => config
    if config.category == "rmd"
  }
}

# -----------------------------------------------------------------------------
# DDL Statements: Raw Layer (Phase 1)
# Create raw tables first (hc_raw_patients, hc_raw_devices, hc_raw_prescriptions, hc_device_metrics)
# -----------------------------------------------------------------------------
resource "confluent_flink_statement" "ddl_raw" {
  for_each = var.deploy_flink_statements ? local.raw_tables : {}

  organization {
    id = data.confluent_organization.my_org.id
  }

  environment {
    id = local.environment_id
  }

  compute_pool {
    id = confluent_flink_compute_pool.pool.id
  }

  principal {
    id = confluent_service_account.demo_app.id
  }

  rest_endpoint = data.confluent_flink_region.flink_region.rest_endpoint

  credentials {
    key    = confluent_api_key.demo_flink.id
    secret = confluent_api_key.demo_flink.secret
  }

  statement      = file(each.value.ddl_path)
  statement_name = "${var.statement_name_prefix}-ddl-${replace(each.key, "_", "-")}"

  properties = local.base_properties

  lifecycle {
    prevent_destroy = false
  }
}

# -----------------------------------------------------------------------------
# DDL Statements: RMD Layer (Phase 2)
# Create rmd/dimension tables after raw tables exist
# -----------------------------------------------------------------------------
resource "confluent_flink_statement" "ddl_rmd" {
  for_each = var.deploy_flink_statements ? local.rmd_tables : {}

  organization {
    id = data.confluent_organization.my_org.id
  }

  environment {
    id = local.environment_id
  }

  compute_pool {
    id = confluent_flink_compute_pool.pool.id
  }

  principal {
    id = confluent_service_account.demo_app.id
  }

  rest_endpoint = data.confluent_flink_region.flink_region.rest_endpoint

  credentials {
    key    = confluent_api_key.demo_flink.id
    secret = confluent_api_key.demo_flink.secret
  }

  statement      = file(each.value.ddl_path)
  statement_name = "${var.statement_name_prefix}-ddl-${replace(each.key, "_", "-")}"

  properties = local.base_properties

  # RMD tables may reference raw tables, so depend on raw DDLs
  depends_on = [
    confluent_flink_statement.ddl_raw
  ]

  lifecycle {
    prevent_destroy = false
  }
}

# -----------------------------------------------------------------------------
# DML Statements: Raw Layer (Phase 3)
# Insert data into raw tables (only for tables with DML)
# -----------------------------------------------------------------------------
resource "confluent_flink_statement" "dml_raw" {
  for_each = var.deploy_flink_statements ? {
    for table_name, table_config in local.raw_tables :
    table_name => table_config
    if table_config.has_dml && table_config.dml_path != null
  } : {}

  organization {
    id = data.confluent_organization.my_org.id
  }

  environment {
    id = local.environment_id
  }

  compute_pool {
    id = confluent_flink_compute_pool.pool.id
  }

  principal {
    id = confluent_service_account.demo_app.id
  }

  rest_endpoint = data.confluent_flink_region.flink_region.rest_endpoint

  credentials {
    key    = confluent_api_key.demo_flink.id
    secret = confluent_api_key.demo_flink.secret
  }

  statement      = file(each.value.dml_path)
  statement_name = "${var.statement_name_prefix}-dml-${replace(each.key, "_", "-")}"

  properties = local.parse_properties[each.key]

  # DML depends on both raw and rmd DDLs being created
  depends_on = [
    confluent_flink_statement.ddl_raw,
    confluent_flink_statement.ddl_rmd
  ]

  lifecycle {
    prevent_destroy = false
  }
}

# -----------------------------------------------------------------------------
# DML Statements: RMD Layer (Phase 4)
# Insert/transform data into rmd tables (only for tables with DML)
# -----------------------------------------------------------------------------
resource "confluent_flink_statement" "dml_rmd" {
  for_each = var.deploy_flink_statements ? {
    for table_name, table_config in local.rmd_tables :
    table_name => table_config
    if table_config.has_dml && table_config.dml_path != null
  } : {}

  organization {
    id = data.confluent_organization.my_org.id
  }

  environment {
    id = local.environment_id
  }

  compute_pool {
    id = confluent_flink_compute_pool.pool.id
  }

  principal {
    id = confluent_service_account.demo_app.id
  }

  rest_endpoint = data.confluent_flink_region.flink_region.rest_endpoint

  credentials {
    key    = confluent_api_key.demo_flink.id
    secret = confluent_api_key.demo_flink.secret
  }

  statement      = file(each.value.dml_path)
  statement_name = "${var.statement_name_prefix}-dml-${replace(each.key, "_", "-")}"

  properties = local.parse_properties[each.key]

  # RMD DML depends on all DDLs and raw DML being created
  depends_on = [
    confluent_flink_statement.ddl_raw,
    confluent_flink_statement.ddl_rmd,
    confluent_flink_statement.dml_raw
  ]

  lifecycle {
    prevent_destroy = false
  }
}
