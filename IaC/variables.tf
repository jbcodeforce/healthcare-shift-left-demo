# Confluent Cloud API credentials (required)

variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key (Cloud API ID)"
  type        = string
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret"
  type        = string
  sensitive   = true
}

# Cloud and region for created resources

variable "cloud_provider" {
  description = "Cloud provider for Kafka and Flink (e.g. AWS, GCP, AZURE)"
  type        = string
  default     = "AWS"
}

variable "cloud_region" {
  description = "Cloud region (e.g. us-east-1, us-west-2)"
  type        = string
  default     = "us-west-2"
}

variable "prefix" {
  description = "Prefix for created resource names"
  type        = string
  default     = "health"
}

# Optional: use existing environment and/or Kafka cluster (skip creation when set)

variable "environment_id" {
  description = "Existing Confluent Cloud environment ID (e.g. env-xxxx). When set, no new environment is created. Required when kafka_cluster_id is set."
  type        = string
  default     = null
}

variable "kafka_cluster_id" {
  description = "Existing Kafka cluster ID (e.g. lkc-xxxx). When set, no new Kafka cluster is created. environment_id must also be set."
  type        = string
  default     = null
}

# Flink compute pool (always created in the target environment)

variable "flink_compute_pool_name" {
  description = "Display name for the Flink compute pool"
  type        = string
  default     = "healthcare-demo-pool"
}

variable "flink_compute_pool_max_cfu" {
  description = "Maximum CFU for the Flink compute pool"
  type        = number
  default     = 5
}

# Flink statement deployment options

variable "deploy_flink_statements" {
  description = "Whether to deploy Flink SQL statements (DDL/DML)"
  type        = bool
  default     = false
}

variable "statement_name_prefix" {
  description = "Prefix for Flink statement names"
  type        = string
  default     = "hc"
}
