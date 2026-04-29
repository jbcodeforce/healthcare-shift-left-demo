# Flink SQL statements (separate state from Confluent core). Deploy from ../pipelines/inventory.json
# Prerequisite: apply the Confluent core stack in the parent directory first (or pass variables manually).

terraform {
  required_version = ">= 1.0"

  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = ">= 2.57.0"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret

  kafka_id                      = ""
  kafka_api_key                 = ""
  kafka_api_secret              = ""
  kafka_rest_endpoint           = ""
  schema_registry_id            = ""
  schema_registry_api_key       = ""
  schema_registry_api_secret    = ""
  schema_registry_rest_endpoint = ""
  catalog_rest_endpoint         = ""
  flink_api_key                 = ""
  flink_api_secret              = ""
  flink_rest_endpoint           = ""
  organization_id               = ""
  environment_id                = ""
  flink_compute_pool_id         = ""
  flink_principal_id            = ""
  tableflow_api_key             = ""
  tableflow_api_secret          = ""
}

# -----------------------------------------------------------------------------
# Confluent core stack (parent IaC) — optional
# -----------------------------------------------------------------------------

data "terraform_remote_state" "confluent" {
  count   = var.use_confluent_remote_state ? 1 : 0
  backend = "local"

  config = {
    path = var.confluent_terraform_state_path != null && var.confluent_terraform_state_path != "" ? var.confluent_terraform_state_path : abspath("${path.module}/../terraform.tfstate")
  }
}

locals {
  cloud_provider = var.use_confluent_remote_state ? data.terraform_remote_state.confluent[0].outputs.cloud_provider : var.cloud_provider
  cloud_region   = var.use_confluent_remote_state ? data.terraform_remote_state.confluent[0].outputs.cloud_region : var.cloud_region

  environment_id        = var.use_confluent_remote_state ? data.terraform_remote_state.confluent[0].outputs.env_id : var.environment_id
  env_display_name      = var.use_confluent_remote_state ? data.terraform_remote_state.confluent[0].outputs.env_display_name : var.env_display_name
  kafka_display_name    = var.use_confluent_remote_state ? data.terraform_remote_state.confluent[0].outputs.kafka_cluster_display_name : var.kafka_cluster_display_name
  flink_compute_pool_id = var.use_confluent_remote_state ? data.terraform_remote_state.confluent[0].outputs.flink_compute_pool_id : var.flink_compute_pool_id
  service_account_id    = var.use_confluent_remote_state ? data.terraform_remote_state.confluent[0].outputs.app_service_account_id : var.service_account_id
  flink_api_key_id      = var.use_confluent_remote_state ? data.terraform_remote_state.confluent[0].outputs.app_flink_api_key_id : var.flink_api_key_id
  flink_api_key_secret  = var.use_confluent_remote_state ? data.terraform_remote_state.confluent[0].outputs.app_flink_api_key_secret : var.flink_api_key_secret

  repo_root = abspath("${path.module}/../..")
}

data "confluent_organization" "my_org" {}

data "confluent_flink_region" "flink_region" {
  cloud  = local.cloud_provider
  region = local.cloud_region
}

# -----------------------------------------------------------------------------
# Inventory and statement locals (from pipelines/inventory.json)
# -----------------------------------------------------------------------------

locals {
  inventory = jsondecode(file("${local.repo_root}/pipelines/inventory.json"))

  base_properties = {
    "sql.current-catalog"  = local.env_display_name
    "sql.current-database" = local.kafka_display_name
  }

  tables = {
    for table_name, config in local.inventory : table_name => {
      table_name      = config.table_name
      product_name    = config.product_name
      type            = config.type
      ddl_path        = "${local.repo_root}/${config.ddl_ref}"
      dml_path        = config.dml_ref != null && config.dml_ref != "" ? "${local.repo_root}/${config.dml_ref}" : null
      properties_path = config.dml_ref != null && config.dml_ref != "" ? "${local.repo_root}/${replace(config.dml_ref, ".sql", ".properties")}" : null
      has_dml         = config.dml_ref != null && config.dml_ref != ""
      category        = config.product_name
    }
  }

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
# Phase 1–4: Flink statements
# -----------------------------------------------------------------------------

resource "confluent_flink_statement" "ddl_raw" {
  for_each = var.deploy_flink_statements ? local.raw_tables : {}

  organization { id = data.confluent_organization.my_org.id }
  environment { id = local.environment_id }
  compute_pool { id = local.flink_compute_pool_id }
  principal { id = local.service_account_id }

  rest_endpoint = data.confluent_flink_region.flink_region.rest_endpoint

  credentials {
    key    = local.flink_api_key_id
    secret = local.flink_api_key_secret
  }

  statement      = file(each.value.ddl_path)
  statement_name = "${var.statement_name_prefix}-ddl-${replace(each.key, "_", "-")}"
  properties     = local.base_properties

  lifecycle { prevent_destroy = false }
}

resource "confluent_flink_statement" "ddl_rmd" {
  for_each = var.deploy_flink_statements ? local.rmd_tables : {}

  organization { id = data.confluent_organization.my_org.id }
  environment { id = local.environment_id }
  compute_pool { id = local.flink_compute_pool_id }
  principal { id = local.service_account_id }

  rest_endpoint = data.confluent_flink_region.flink_region.rest_endpoint

  credentials {
    key    = local.flink_api_key_id
    secret = local.flink_api_key_secret
  }

  statement      = file(each.value.ddl_path)
  statement_name = "${var.statement_name_prefix}-ddl-${replace(each.key, "_", "-")}"
  properties     = local.base_properties

  depends_on = [confluent_flink_statement.ddl_raw]

  lifecycle { prevent_destroy = false }
}

resource "confluent_flink_statement" "dml_raw" {
  for_each = var.deploy_flink_statements ? {
    for table_name, table_config in local.raw_tables :
    table_name => table_config
    if table_config.has_dml && table_config.dml_path != null
  } : {}

  organization { id = data.confluent_organization.my_org.id }
  environment { id = local.environment_id }
  compute_pool { id = local.flink_compute_pool_id }
  principal { id = local.service_account_id }

  rest_endpoint = data.confluent_flink_region.flink_region.rest_endpoint

  credentials {
    key    = local.flink_api_key_id
    secret = local.flink_api_key_secret
  }

  statement      = file(each.value.dml_path)
  statement_name = "${var.statement_name_prefix}-dml-${replace(each.key, "_", "-")}"
  properties     = local.parse_properties[each.key]

  depends_on = [confluent_flink_statement.ddl_raw, confluent_flink_statement.ddl_rmd]

  lifecycle { prevent_destroy = false }
}

resource "confluent_flink_statement" "dml_rmd" {
  for_each = var.deploy_flink_statements ? {
    for table_name, table_config in local.rmd_tables :
    table_name => table_config
    if table_config.has_dml && table_config.dml_path != null
  } : {}

  organization { id = data.confluent_organization.my_org.id }
  environment { id = local.environment_id }
  compute_pool { id = local.flink_compute_pool_id }
  principal { id = local.service_account_id }

  rest_endpoint = data.confluent_flink_region.flink_region.rest_endpoint

  credentials {
    key    = local.flink_api_key_id
    secret = local.flink_api_key_secret
  }

  statement      = file(each.value.dml_path)
  statement_name = "${var.statement_name_prefix}-dml-${replace(each.key, "_", "-")}"
  properties     = local.parse_properties[each.key]

  depends_on = [confluent_flink_statement.ddl_raw, confluent_flink_statement.ddl_rmd, confluent_flink_statement.dml_raw]

  lifecycle { prevent_destroy = false }
}
