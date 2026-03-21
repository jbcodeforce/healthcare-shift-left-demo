# Schema Registry is provisioned with the environment when stream_governance.package = "ESSENTIALS"
# (see env.tf). There is no confluent_schema_registry_cluster *resource* in provider 2.x; this data
# source resolves the cluster for the target environment.

data "confluent_schema_registry_cluster" "essentials" {
  environment {
    id = local.environment_id
  }

  depends_on = [
    confluent_kafka_cluster.kafka,
    data.confluent_kafka_cluster.existing,
  ]
}

locals {
  schema_registry = data.confluent_schema_registry_cluster.essentials
}
