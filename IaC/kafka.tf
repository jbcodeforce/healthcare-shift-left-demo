# Kafka cluster: create new or use existing (via kafka_cluster_id variable)

locals {
  use_existing_kafka = var.kafka_cluster_id != null && var.kafka_cluster_id != ""
}

resource "confluent_kafka_cluster" "kafka" {
  count        = local.use_existing_kafka ? 0 : 1
  display_name = "${var.prefix}-kafka"
  availability = "SINGLE_ZONE"
  cloud        = var.cloud_provider
  region       = var.cloud_region
  standard {}

  environment {
    id = local.environment_id
  }
}

data "confluent_kafka_cluster" "existing" {
  count = local.use_existing_kafka ? 1 : 0
  id    = var.kafka_cluster_id
  environment {
    id = local.environment_id
  }
}

locals {
  kafka_cluster_id    = local.use_existing_kafka ? data.confluent_kafka_cluster.existing[0].id : confluent_kafka_cluster.kafka[0].id
  kafka_bootstrap     = local.use_existing_kafka ? data.confluent_kafka_cluster.existing[0].bootstrap_endpoint : confluent_kafka_cluster.kafka[0].bootstrap_endpoint
  kafka_rest_endpoint = local.use_existing_kafka ? data.confluent_kafka_cluster.existing[0].rest_endpoint : confluent_kafka_cluster.kafka[0].rest_endpoint
  kafka_display_name  = local.use_existing_kafka ? data.confluent_kafka_cluster.existing[0].display_name : confluent_kafka_cluster.kafka[0].display_name
  kafka_rbac_crn      = local.use_existing_kafka ? data.confluent_kafka_cluster.existing[0].rbac_crn : confluent_kafka_cluster.kafka[0].rbac_crn
}
