#!/usr/bin/env bash
# Export TF_VAR_* from the environment (typically after backend/.env is loaded) for Terraform in IaC/.
# If CONFLUENT_CLOUD_API_KEY is unset, sources set_env_var first.
# Usage: source ./export_terraform_env.sh && cd IaC && terraform plan


_REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"


if [[ -z "${CONFLUENT_CLOUD_API_KEY:-}" ]]; then
  # shellcheck source=/dev/null
  source "$_REPO_ROOT/set_env_var" || return 1 2>/dev/null || exit 1
fi

_tf_upper() { printf '%s' "$1" | tr '[:lower:]' '[:upper:]'; }

[[ -n "${CONFLUENT_CLOUD_API_KEY:-}" ]] && export TF_VAR_confluent_cloud_api_key="$CONFLUENT_CLOUD_API_KEY"
[[ -n "${CONFLUENT_CLOUD_API_SECRET:-}" ]] && export TF_VAR_confluent_cloud_api_secret="$CONFLUENT_CLOUD_API_SECRET"

[[ -n "${CLOUD_PROVIDER:-}" ]] && export TF_VAR_cloud_provider="$(_tf_upper "$CLOUD_PROVIDER")"
[[ -n "${CLOUD_REGION:-}" ]] && export TF_VAR_cloud_region="$CLOUD_REGION"

_env_id="${ENVIRONMENT_ID:-}"
[[ -z "$_env_id" ]] && _env_id="${FLINK_ENV_ID:-}"
[[ -z "$_env_id" ]] && _env_id="${ENV_ID:-}"
[[ -n "$_env_id" ]] && export TF_VAR_environment_id="$_env_id"

[[ -n "${KAFKA_CLUSTER_ID:-}" ]] && export TF_VAR_kafka_cluster_id="$KAFKA_CLUSTER_ID"

# Kafka / Schema Registry / Flink API keys are created by Terraform (app_credentials.tf).
# After apply, use: cd IaC && terraform output -raw backend_env_snippet
# Do not map FLINK_* or PRINCIPAL_ID to TF_VAR_* (those variables were removed).

[[ -n "${PREFIX:-}" ]] && export TF_VAR_prefix="$PREFIX"
[[ -n "${FLINK_COMPUTE_POOL_NAME:-}" ]] && export TF_VAR_flink_compute_pool_name="$FLINK_COMPUTE_POOL_NAME"
[[ -n "${STATEMENT_NAME_PREFIX:-}" ]] && export TF_VAR_statement_name_prefix="$STATEMENT_NAME_PREFIX"

if [[ -n "${DEPLOY_FLINK_STATEMENTS:-}" ]]; then
  _dfs=$(printf '%s' "$DEPLOY_FLINK_STATEMENTS" | tr '[:upper:]' '[:lower:]')
  case "$_dfs" in
    true | 1 | yes) export TF_VAR_deploy_flink_statements=true ;;
    false | 0 | no) export TF_VAR_deploy_flink_statements=false ;;
  esac
fi
