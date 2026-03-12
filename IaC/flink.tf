# Flink compute pool (always created in the target environment)

resource "confluent_flink_compute_pool" "pool" {
  display_name = var.flink_compute_pool_name
  cloud        = upper(data.confluent_flink_region.flink_region.cloud)
  region       = data.confluent_flink_region.flink_region.region
  max_cfu      = var.flink_compute_pool_max_cfu

  environment {
    id = local.environment_id
  }
}
