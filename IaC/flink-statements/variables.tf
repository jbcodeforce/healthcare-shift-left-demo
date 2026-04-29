variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API key (same as Confluent core stack / Cloud API)"
  type        = string
  sensitive   = true
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API secret"
  type        = string
  sensitive   = true
}

# Read IDs and keys from the Confluent core stack state (IaC/terraform.tfstate)
variable "use_confluent_remote_state" {
  description = "When true, read environment_id, pool, service account, Flink key, and cloud settings from terraform_remote_state"
  type        = bool
  default     = true
}

variable "confluent_terraform_state_path" {
  description = "Path to the Confluent core terraform.tfstate (default: parent IaC directory)"
  type        = string
  default     = null
  nullable    = true
}

# Used when use_confluent_remote_state is false
variable "cloud_provider" {
  type    = string
  default = "AWS"
}

variable "cloud_region" {
  type    = string
  default = "us-west-2"
}

variable "environment_id" {
  description = "Confluent environment id (e.g. env-xxx); required if use_confluent_remote_state is false"
  type        = string
  default     = null
  nullable    = true
}

variable "env_display_name" {
  description = "Environment display name for sql.current-catalog; required if use_confluent_remote_state is false"
  type        = string
  default     = null
  nullable    = true
}

variable "kafka_cluster_display_name" {
  description = "Kafka cluster display name for sql.current-database; required if use_confluent_remote_state is false"
  type        = string
  default     = null
  nullable    = true
}

variable "flink_compute_pool_id" {
  type     = string
  default  = null
  nullable = true
}

variable "service_account_id" {
  type     = string
  default  = null
  nullable = true
}

variable "flink_api_key_id" {
  type     = string
  default  = null
  nullable = true
}

variable "flink_api_key_secret" {
  type     = string
  default  = null
  nullable = true
}

variable "deploy_flink_statements" {
  description = "Whether to create or update Flink SQL statements"
  type        = bool
  default     = true
}

variable "statement_name_prefix" {
  type    = string
  default = "hc"
}
