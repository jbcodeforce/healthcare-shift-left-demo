# Outputs for Confluent Cloud resources

locals {
  backend_env_snippet = join("\n", [
    "KAFKA_BOOTSTRAP_SERVERS=\"${local.kafka_bootstrap}\"",
    "KAFKA_REST_ENDPOINT=\"${local.kafka_rest_endpoint}\"",
    "KAFKA_CLUSTER_ID=\"${local.kafka_cluster_id}\"",
    "KAFKA_API_KEY=${local.kafka_api_key_id}",
    "KAFKA_API_SECRET=${local.kafka_api_key_secret}",
    "KAFKA_SASL_USERNAME=${local.kafka_api_key_id}",
    "KAFKA_SASL_PASSWORD=${local.kafka_api_key_secret}",
    "SCHEMA_REGISTRY_URL=\"${local.schema_registry.rest_endpoint}\"",
    "SCHEMA_REGISTRY_BASIC_AUTH_USER_INFO=${local.schema_registry_api_key_id}:${local.schema_registry_api_key_secret}",
    "FLINK_API_KEY=${local.flink_api_key_id}",
    "FLINK_API_SECRET=${local.flink_api_key_secret}",
    "FLINK_REST_ENDPOINT=${data.confluent_flink_region.flink_region.rest_endpoint}",
    "PRINCIPAL_ID=${local.service_account_id}",
    "FLINK_COMPUTE_POOL_ID=${local.flink_compute_pool_id}",
  ])
}

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
# Demo app credentials (Terraform-managed API keys)
# ------------------------------------------------------

output "app_service_account_id" {
  description = "Service account ID for demo app (PRINCIPAL_ID for Flink / backend)"
  value       = local.service_account_id
}

output "app_kafka_api_key_id" {
  description = "Kafka API key id (KAFKA_API_KEY)"
  value       = local.kafka_api_key_id
  sensitive   = true
}

output "app_kafka_api_key_secret" {
  description = "Kafka API key secret (KAFKA_API_SECRET)"
  value       = local.kafka_api_key_secret
  sensitive   = true
}

output "app_schema_registry_api_key_id" {
  description = "Schema Registry API key id (with secret forms SCHEMA_REGISTRY_BASIC_AUTH_USER_INFO)"
  value       = local.schema_registry_api_key_id
  sensitive   = true
}

output "app_schema_registry_api_key_secret" {
  description = "Schema Registry API key secret"
  value       = local.schema_registry_api_key_secret
  sensitive   = true
}

output "app_flink_api_key_id" {
  description = "Flink API key id (FLINK_API_KEY)"
  value       = local.flink_api_key_id
  sensitive   = true
}

output "app_flink_api_key_secret" {
  description = "Flink API key secret (FLINK_API_SECRET)"
  value       = local.flink_api_key_secret
  sensitive   = true
}

output "backend_env" {
  description = "Map of common backend/.env variable names to values (all sensitive)"
  sensitive   = true
  value = {
    KAFKA_BOOTSTRAP_SERVERS              = local.kafka_bootstrap
    KAFKA_REST_ENDPOINT                  = local.kafka_rest_endpoint
    KAFKA_CLUSTER_ID                     = local.kafka_cluster_id
    KAFKA_API_KEY                        = local.kafka_api_key_id
    KAFKA_API_SECRET                     = local.kafka_api_key_secret
    KAFKA_SASL_USERNAME                  = local.kafka_api_key_id
    KAFKA_SASL_PASSWORD                  = local.kafka_api_key_secret
    SCHEMA_REGISTRY_URL                  = local.schema_registry.rest_endpoint
    SCHEMA_REGISTRY_BASIC_AUTH_USER_INFO = "${local.schema_registry_api_key_id}:${local.schema_registry_api_key_secret}"
    FLINK_API_KEY                        = local.flink_api_key_id
    FLINK_API_SECRET                     = local.flink_api_key_secret
    FLINK_REST_ENDPOINT                  = data.confluent_flink_region.flink_region.rest_endpoint
    PRINCIPAL_ID                         = local.service_account_id
    FLINK_COMPUTE_POOL_ID                = local.flink_compute_pool_id
  }
}

output "backend_env_snippet" {
  description = "Multiline text to append or merge into backend/.env (contains secrets; do not commit)"
  value       = local.backend_env_snippet
  sensitive   = true
}

# ------------------------------------------------------
# Flink Resources
# ------------------------------------------------------
output "flink_compute_pool_id" {
  description = "Flink compute pool ID"
  value       = local.flink_compute_pool_id
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

# ------------------------------------------------------
# Tableflow and S3
# ------------------------------------------------------

output "s3_analytics_bucket" {
  description = "S3 bucket name for analytics data"
  value       = var.enable_tableflow ? aws_s3_bucket.analytics[0].bucket : null
}

output "s3_analytics_bucket_arn" {
  description = "S3 bucket ARN for analytics data"
  value       = var.enable_tableflow ? aws_s3_bucket.analytics[0].arn : null
}

output "s3_analytics_bucket_region" {
  description = "S3 bucket region"
  value       = var.enable_tableflow ? aws_s3_bucket.analytics[0].region : null
}

output "tableflow_iam_role_arn" {
  description = "IAM role ARN for Confluent Tableflow"
  value       = var.enable_tableflow ? aws_iam_role.tableflow[0].arn : null
}

output "analytics_s3_paths" {
  description = "S3 paths for analytics data (Tableflow connections must be created manually via Confluent UI)"
  value = var.enable_tableflow ? {
    anomalies            = "s3://${aws_s3_bucket.analytics[0].bucket}/anomalies"
    prescription_changes = "s3://${aws_s3_bucket.analytics[0].bucket}/prescription_changes"
    telemetries          = "s3://${aws_s3_bucket.analytics[0].bucket}/telemetries"
  } : {}
}

output "tableflow_note" {
  description = "Tableflow setup instructions"
  value       = var.enable_tableflow ? "Tableflow infrastructure created! Configure Tableflow connections manually via Confluent UI. See TABLEFLOW_SETUP_GUIDE.md for instructions." : "Tableflow not enabled. Set enable_tableflow=true in terraform.tfvars"
}
