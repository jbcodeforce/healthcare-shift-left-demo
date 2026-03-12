# Confluent Cloud environment: create new or use existing (via environment_id variable)

locals {
  use_existing_env = var.environment_id != null && var.environment_id != ""
}

resource "confluent_environment" "env" {
  count         = local.use_existing_env ? 0 : 1
  display_name  = "${var.prefix}-env"
  stream_governance {
    package = "ESSENTIALS"
  }
}

locals {
  environment_id   = local.use_existing_env ? var.environment_id : confluent_environment.env[0].id
  env_display_name = local.use_existing_env ? null : confluent_environment.env[0].display_name
}
