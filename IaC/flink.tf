# Flink compute pool: create new or use existing (via flink_compute_pool_id variable)

locals {
  use_existing_flink_pool = var.flink_compute_pool_id != null && var.flink_compute_pool_id != ""
}

resource "confluent_flink_compute_pool" "pool" {
  count        = local.use_existing_flink_pool ? 0 : 1
  display_name = var.flink_compute_pool_name
  cloud        = upper(data.confluent_flink_region.flink_region.cloud)
  region       = data.confluent_flink_region.flink_region.region
  max_cfu      = var.flink_compute_pool_max_cfu

  environment {
    id = local.environment_id
  }
}

data "confluent_flink_compute_pool" "existing" {
  count = local.use_existing_flink_pool ? 1 : 0
  id    = var.flink_compute_pool_id
  environment {
    id = local.environment_id
  }
}

locals {
  flink_compute_pool_id            = local.use_existing_flink_pool ? data.confluent_flink_compute_pool.existing[0].id : confluent_flink_compute_pool.pool[0].id
  flink_compute_pool_resource_name = local.use_existing_flink_pool ? data.confluent_flink_compute_pool.existing[0].resource_name : confluent_flink_compute_pool.pool[0].resource_name
}
