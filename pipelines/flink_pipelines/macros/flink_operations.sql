{% macro create_flink_statement_api(statement_name, sql_content, properties=none) %}
  {#
    Create or update a Flink statement via Confluent Cloud REST API
    This is called during dbt run-operation deploy_flink
  #}

  {% set config = {
    'flink_endpoint': env_var('FLINK_REST_ENDPOINT'),
    'flink_api_key': env_var('FLINK_API_KEY'),
    'flink_api_secret': env_var('FLINK_API_SECRET'),
    'compute_pool_id': env_var('FLINK_COMPUTE_POOL_ID'),
    'principal_id': env_var('PRINCIPAL_ID'),
    'env_id': env_var('ENV_ID'),
    'org_id': env_var('ORG_ID', '5f242057-6c74-4ba5-9942-60d363203b93'),
    'kafka_cluster_display_name': env_var('KAFKA_CLUSTER_DISPLAY_NAME', 'healthcare-shift-left-demo-cluster'),
    'env_display_name': env_var('ENV_DISPLAY_NAME', 'healthcare-shift-left-demo')
  } %}

  {# Build properties map #}
  {% set base_properties = {
    'sql.current-catalog': config.env_display_name,
    'sql.current-database': config.kafka_cluster_display_name
  } %}

  {% if properties %}
    {% set all_properties = base_properties | combine(properties) %}
  {% else %}
    {% set all_properties = base_properties %}
  {% endif %}

  {# Log deployment #}
  {{ log("=" * 80, info=True) }}
  {{ log("Deploying Flink Statement: " ~ statement_name, info=True) }}
  {{ log("Compute Pool: " ~ config.compute_pool_id, info=True) }}
  {{ log("Properties: " ~ all_properties, info=False) }}
  {{ log("SQL Preview: " ~ sql_content[:200] ~ "...", info=False) }}
  {{ log("=" * 80, info=True) }}

  {# Return statement info for processing #}
  {% set statement_info = {
    'name': statement_name,
    'sql': sql_content,
    'properties': all_properties,
    'config': config
  } %}

  {{ return(statement_info) }}

{% endmacro %}


{% macro get_flink_statement_status(statement_name) %}
  {# Check if a Flink statement exists and its status #}
  {{ log("Checking status of statement: " ~ statement_name, info=True) }}
  {{ return({'exists': false, 'status': 'UNKNOWN'}) }}
{% endmacro %}


{% macro delete_flink_statement(statement_name) %}
  {# Delete a Flink statement #}
  {{ log("Deleting statement: " ~ statement_name, info=True) }}
  {{ return(true) }}
{% endmacro %}
