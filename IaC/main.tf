# Terraform configuration for healthcare-shift-left-demo
# Confluent Cloud: environment, Kafka cluster, Flink compute pool

terraform {
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

  # Flink-specific configuration for statement deployment
  flink_rest_endpoint   = var.flink_api_key != "" ? data.confluent_flink_region.flink_region.rest_endpoint : null
  flink_compute_pool_id = var.flink_api_key != "" ? confluent_flink_compute_pool.pool.id : null
  flink_api_key         = var.flink_api_key != "" ? var.flink_api_key : null
  flink_api_secret      = var.flink_api_secret != "" ? var.flink_api_secret : null
  flink_principal_id    = var.flink_principal_id != "" ? var.flink_principal_id : null
}

# Data sources for organization and Flink region

data "confluent_organization" "my_org" {}

data "confluent_flink_region" "flink_region" {
  cloud  = var.cloud_provider
  region = var.cloud_region
}

# Data source for environment display name (needed for Flink statement properties)
# Only fetched when using existing environment
data "confluent_environment" "existing" {
  count = local.use_existing_env ? 1 : 0
  id    = var.environment_id
}
