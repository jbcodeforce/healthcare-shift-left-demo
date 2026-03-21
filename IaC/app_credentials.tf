# Demo application service account, RBAC, and cluster API keys (Kafka, Schema Registry, Flink).
# Key secrets are in Terraform state; use outputs to populate backend/.env after apply.

resource "confluent_service_account" "demo_app" {
  display_name = "${var.prefix}-demo-app"
  description  = "Healthcare demo: backend, Connect, and Flink statements"
}

resource "confluent_role_binding" "demo_app_kafka_cluster_admin" {
  principal   = "User:${confluent_service_account.demo_app.id}"
  role_name   = "CloudClusterAdmin"
  crn_pattern = local.kafka_rbac_crn
}

# DataSteward is not accepted on SchemaRegistry cluster CRNs; bind at environment scope instead
# (crn://.../environment=env-... only). Same role covers Schema Registry in that environment.
resource "confluent_role_binding" "demo_app_schema_registry" {
  principal   = "User:${confluent_service_account.demo_app.id}"
  role_name   = "DataSteward"
  crn_pattern = local.environment_resource_name
}

resource "confluent_role_binding" "demo_app_flink_developer" {
  principal   = "User:${confluent_service_account.demo_app.id}"
  role_name   = "FlinkDeveloper"
  crn_pattern = confluent_flink_compute_pool.pool.resource_name
}

resource "confluent_api_key" "demo_kafka" {
  display_name = "${var.prefix}-demo-kafka"
  description  = "Kafka cluster API key for ${var.prefix}-demo-app"
  owner {
    id          = confluent_service_account.demo_app.id
    api_version = confluent_service_account.demo_app.api_version
    kind        = confluent_service_account.demo_app.kind
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

resource "confluent_api_key" "demo_schema_registry" {
  display_name = "${var.prefix}-demo-schema-registry"
  description  = "Schema Registry API key for ${var.prefix}-demo-app"
  owner {
    id          = confluent_service_account.demo_app.id
    api_version = confluent_service_account.demo_app.api_version
    kind        = confluent_service_account.demo_app.kind
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

resource "confluent_api_key" "demo_flink" {
  display_name = "${var.prefix}-demo-flink"
  description  = "Flink API key for ${var.prefix}-demo-app"
  owner {
    id          = confluent_service_account.demo_app.id
    api_version = confluent_service_account.demo_app.api_version
    kind        = confluent_service_account.demo_app.kind
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
