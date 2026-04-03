{% macro deploy_to_flink(sql_content, statement_name, properties=none) %}
  {#
    Custom macro to deploy SQL to Confluent Flink via REST API
    This replaces the need for actual postgres materialization
  #}

  {% set flink_endpoint = var('flink_rest_endpoint', env_var('FLINK_REST_ENDPOINT')) %}
  {% set flink_api_key = var('flink_api_key', env_var('FLINK_API_KEY')) %}
  {% set flink_api_secret = var('flink_api_secret', env_var('FLINK_API_SECRET')) %}
  {% set compute_pool_id = var('flink_compute_pool_id', env_var('FLINK_COMPUTE_POOL_ID')) %}
  {% set principal_id = var('principal_id', env_var('PRINCIPAL_ID')) %}
  {% set env_id = var('environment_id', env_var('ENV_ID')) %}
  {% set org_id = var('organization_id', env_var('ORG_ID', '5f242057-6c74-4ba5-9942-60d363203b93')) %}

  {{ log("Deploying Flink statement: " ~ statement_name, info=True) }}
  {{ log("Endpoint: " ~ flink_endpoint, info=False) }}

  {# This is a placeholder - actual deployment happens via run-operation #}
  {# Return the SQL content for logging/debugging #}
  {{ return(sql_content) }}

{% endmacro %}


{% macro read_sql_file(file_path) %}
  {#
    Read SQL file from filesystem
    Used to load DDL/DML from existing sql-scripts directories
  #}
  {% set sql_content = "" %}

  {# Try to read the file - this is a simplified version #}
  {# In practice, this would use dbt's file reading capabilities #}
  {{ log("Loading SQL from: " ~ file_path, info=False) }}

  {% set sql_content = load_file(file_path) %}
  {{ return(sql_content) }}

{% endmacro %}


{% macro load_file(filepath) %}
  {# Helper to load file content #}
  {% set ns = namespace(content='') %}

  {# This uses Jinja's include to load file content #}
  {% set content %}
    {% include filepath ignore missing %}
  {% endset %}

  {{ return(content if content else '-- File not found: ' ~ filepath) }}
{% endmacro %}
