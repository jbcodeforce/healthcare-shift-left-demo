# Outputs for Confluent Cloud resources

output "env_id" {
  description = "Confluent Cloud environment ID"
  value       = local.environment_id
}

output "env_display_name" {
  description = "Environment display name (null when using existing environment)"
  value       = local.env_display_name
}

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

output "flink_compute_pool_id" {
  description = "Flink compute pool ID"
  value       = confluent_flink_compute_pool.pool.id
}

output "flink_rest_endpoint" {
  description = "Flink region REST endpoint"
  value       = data.confluent_flink_region.flink_region.rest_endpoint
}
