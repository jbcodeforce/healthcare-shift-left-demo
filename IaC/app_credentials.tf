# Demo application service account, RBAC, and cluster API keys (Kafka, Schema Registry, Flink).
# Key secrets are in Terraform state; use outputs to populate backend/.env after apply.

locals {
  use_existing_service_account = var.service_account_id != null && var.service_account_id != ""
  use_existing_kafka_api_key   = var.kafka_api_key_id != null && var.kafka_api_key_id != ""
  use_existing_sr_api_key      = var.schema_registry_api_key_id != null && var.schema_registry_api_key_id != ""
  use_existing_flink_api_key   = var.flink_api_key_id != null && var.flink_api_key_id != ""
  demo_service_account_display_name = (
    var.service_account_display_name != null && trimspace(var.service_account_display_name) != ""
  ) ? trimspace(var.service_account_display_name) : "${var.prefix}-demo-app"
}

resource "confluent_service_account" "demo_app" {
  count        = local.use_existing_service_account ? 0 : 1
  display_name = local.demo_service_account_display_name
  description  = "Healthcare demo: backend, Connect, and Flink statements"
}

data "confluent_service_account" "existing" {
  count = local.use_existing_service_account ? 1 : 0
  id    = var.service_account_id
}

locals {
  service_account_id = local.use_existing_service_account ? data.confluent_service_account.existing[0].id : confluent_service_account.demo_app[0].id
}

resource "confluent_role_binding" "demo_app_kafka_cluster_admin" {
  principal   = "User:${local.service_account_id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = local.kafka_rbac_crn
}

# DataSteward is not accepted on SchemaRegistry cluster CRNs; bind at environment scope instead
# (crn://.../environment=env-... only). Same role covers Schema Registry in that environment.
resource "confluent_role_binding" "demo_app_schema_registry" {
  principal   = "User:${local.service_account_id}"
  role_name   = "DataSteward"
  crn_pattern = local.environment_resource_name
}

resource "confluent_role_binding" "demo_app_flink_developer" {
  principal   = "User:${local.service_account_id}"
  role_name   = "FlinkDeveloper"
  crn_pattern = local.flink_compute_pool_resource_name
}

resource "confluent_api_key" "demo_kafka" {
  count        = local.use_existing_kafka_api_key ? 0 : 1
  display_name = "${var.prefix}-demo-kafka"
  description  = "Kafka cluster API key for ${var.prefix}-demo-app"
  owner {
    id          = local.service_account_id
    api_version = local.use_existing_service_account ? data.confluent_service_account.existing[0].api_version : confluent_service_account.demo_app[0].api_version
    kind        = local.use_existing_service_account ? data.confluent_service_account.existing[0].kind : confluent_service_account.demo_app[0].kind
  }
  managed_resource {
    id          = local.use_existing_kafka ? data.confluent_kafka_cluster.existing[0].id : confluent_kafka_cluster.kafka[0].id
    api_version = local.use_existing_kafka ? data.confluent_kafka_cluster.existing[0].api_version : confluent_kafka_cluster.kafka[0].api_version
    kind        = local.use_existing_kafka ? data.confluent_kafka_cluster.existing[0].kind : confluent_kafka_cluster.kafka[0].kind
    environment {
      id = local.environment_id
    }
  }
  depends_on = [confluent_role_binding.demo_app_kafka_cluster_admin]
}

locals {
  kafka_api_key_id     = local.use_existing_kafka_api_key ? var.kafka_api_key_id : confluent_api_key.demo_kafka[0].id
  kafka_api_key_secret = local.use_existing_kafka_api_key ? var.kafka_api_key_secret : confluent_api_key.demo_kafka[0].secret
}

resource "confluent_api_key" "demo_schema_registry" {
  count        = local.use_existing_sr_api_key ? 0 : 1
  display_name = "${var.prefix}-demo-schema-registry"
  description  = "Schema Registry API key for ${var.prefix}-demo-app"
  owner {
    id          = local.service_account_id
    api_version = local.use_existing_service_account ? data.confluent_service_account.existing[0].api_version : confluent_service_account.demo_app[0].api_version
    kind        = local.use_existing_service_account ? data.confluent_service_account.existing[0].kind : confluent_service_account.demo_app[0].kind
  }
  managed_resource {
    id          = local.schema_registry.id
    api_version = local.schema_registry.api_version
    kind        = local.schema_registry.kind
    environment {
      id = local.environment_id
    }
  }
  depends_on = [confluent_role_binding.demo_app_schema_registry]
}

locals {
  schema_registry_api_key_id     = local.use_existing_sr_api_key ? var.schema_registry_api_key_id : confluent_api_key.demo_schema_registry[0].id
  schema_registry_api_key_secret = local.use_existing_sr_api_key ? var.schema_registry_api_key_secret : confluent_api_key.demo_schema_registry[0].secret
}

resource "confluent_api_key" "demo_flink" {
  count        = local.use_existing_flink_api_key ? 0 : 1
  display_name = "${var.prefix}-demo-flink"
  description  = "Flink API key for ${var.prefix}-demo-app"
  owner {
    id          = local.service_account_id
    api_version = local.use_existing_service_account ? data.confluent_service_account.existing[0].api_version : confluent_service_account.demo_app[0].api_version
    kind        = local.use_existing_service_account ? data.confluent_service_account.existing[0].kind : confluent_service_account.demo_app[0].kind
  }
  managed_resource {
    id          = data.confluent_flink_region.flink_region.id
    api_version = data.confluent_flink_region.flink_region.api_version
    kind        = data.confluent_flink_region.flink_region.kind
    environment {
      id = local.environment_id
    }
  }
  depends_on = [
    confluent_role_binding.demo_app_flink_developer,
    confluent_flink_compute_pool.pool,
  ]
}

locals {
  flink_api_key_id     = local.use_existing_flink_api_key ? var.flink_api_key_id : confluent_api_key.demo_flink[0].id
  flink_api_key_secret = local.use_existing_flink_api_key ? var.flink_api_key_secret : confluent_api_key.demo_flink[0].secret
}
