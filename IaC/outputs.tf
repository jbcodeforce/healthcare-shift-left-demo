# Outputs for Confluent Cloud resources

output "env_id" {
  description = "Confluent Cloud environment ID"
  value       = local.environment_id
}

output "env_display_name" {
  description = "Environment display name (null when using existing environment)"
  value       = local.env_display_name
}

# ------------------------------------------------------
# Kafka Cluster
# ------------------------------------------------------
output "kafka_cluster_id" {
  description = "Kafka cluster ID"
  value       = local.kafka_cluster_id
}

output "kafka_cluster_display_name" {
  description = "Kafka cluster display name"
  value       = local.kafka_display_name
}

output "kafka_bootstrap_endpoint" {
  description = "Kafka bootstrap endpoint"
  value       = local.kafka_bootstrap
}

output "kafka_rest_endpoint" {
  description = "Kafka REST endpoint"
  value       = local.kafka_rest_endpoint
}


# ------------------------------------------------------
# Schema Registry
# ------------------------------------------------------

output "schema_registry_id" {
  description = "Schema Registry cluster ID"
  value       = local.schema_registry.id
}

output "schema_registry_endpoint" {
  description = "Schema Registry REST API endpoint (HTTPS URL for clients)"
  value       = local.schema_registry.rest_endpoint
}

output "schema_registry_rest_endpoint" {
  description = "Schema Registry REST endpoint (same as schema_registry_endpoint)"
  value       = local.schema_registry.rest_endpoint
}

# ------------------------------------------------------
# Flink Resources
# ------------------------------------------------------
output "flink_compute_pool_id" {
  description = "Flink compute pool ID"
  value       = confluent_flink_compute_pool.pool.id
}

output "flink_rest_endpoint" {
  description = "Flink region REST endpoint"
  value       = data.confluent_flink_region.flink_region.rest_endpoint
}

output "flink_statements_ddl_raw" {
  description = "Raw layer DDL statement IDs"
  value = var.deploy_flink_statements ? {
    for k, v in confluent_flink_statement.ddl_raw : k => {
      id   = v.id
      name = v.statement_name
    }
  } : {}
}

output "flink_statements_ddl_rmd" {
  description = "RMD layer DDL statement IDs"
  value = var.deploy_flink_statements ? {
    for k, v in confluent_flink_statement.ddl_rmd : k => {
      id   = v.id
      name = v.statement_name
    }
  } : {}
}

output "flink_statements_dml_raw" {
  description = "Raw layer DML statement IDs"
  value = var.deploy_flink_statements ? {
    for k, v in confluent_flink_statement.dml_raw : k => {
      id   = v.id
      name = v.statement_name
    }
  } : {}
}

output "flink_statements_dml_rmd" {
  description = "RMD layer DML statement IDs"
  value = var.deploy_flink_statements ? {
    for k, v in confluent_flink_statement.dml_rmd : k => {
      id   = v.id
      name = v.statement_name
    }
  } : {}
}
