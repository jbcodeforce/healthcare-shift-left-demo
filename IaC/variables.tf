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

# Optional: use existing service account (skip creation when set)

variable "service_account_id" {
  description = "Existing service account ID (e.g. sa-xxxx). When set, no new service account is created. API keys will still be created for this service account."
  type        = string
  default     = null
}

# Optional: use existing Flink compute pool (skip creation when set)

variable "flink_compute_pool_id" {
  description = "Existing Flink compute pool ID (e.g. lfcp-xxxx). When set, no new Flink compute pool is created. environment_id must also be set."
  type        = string
  default     = null
}

# Optional: use existing API keys (skip creation when set)

variable "kafka_api_key_id" {
  description = "Existing Kafka API key ID. When set, no new Kafka API key is created."
  type        = string
  default     = null
  sensitive   = true
}

variable "kafka_api_key_secret" {
  description = "Existing Kafka API key secret. Required when kafka_api_key_id is set."
  type        = string
  default     = null
  sensitive   = true
}

variable "schema_registry_api_key_id" {
  description = "Existing Schema Registry API key ID. When set, no new Schema Registry API key is created."
  type        = string
  default     = null
  sensitive   = true
}

variable "schema_registry_api_key_secret" {
  description = "Existing Schema Registry API key secret. Required when schema_registry_api_key_id is set."
  type        = string
  default     = null
  sensitive   = true
}

variable "flink_api_key_id" {
  description = "Existing Flink API key ID. When set, no new Flink API key is created."
  type        = string
  default     = null
  sensitive   = true
}

variable "flink_api_key_secret" {
  description = "Existing Flink API key secret. Required when flink_api_key_id is set."
  type        = string
  default     = null
  sensitive   = true
}

# Tableflow and S3 configuration

variable "enable_tableflow" {
  description = "Enable Tableflow to write Flink data to S3 (requires AWS credentials)"
  type        = bool
  default     = false
}

variable "confluent_aws_account_id" {
  description = "Confluent AWS account ID for Tableflow IAM role trust relationship"
  type        = string
  default     = "761327592718" # Confluent's AWS account ID for Tableflow
}

variable "confluent_external_id" {
  description = "External ID for Confluent Tableflow IAM role assumption (provided by Confluent)"
  type        = string
  default     = ""
  sensitive   = true
}
