{% macro deploy_flink_pipelines(layer=none) %}
  {#
    dbt cannot submit Flink statements from Jinja (no HTTP/subprocess). This macro
    documents the supported command; run it in a shell from the dbt project directory.

    Workflow:
      1. When pipelines/inventory.json changes: python3 generate_flink_models.py
      2. Deploy: python3 dbt_flink_deploy.py --all   (runs dbt compile + REST)

    Or print this reminder from repo root:
      dbt run-operation deploy_flink_pipelines --project-dir pipelines/flink_pipelines --profiles-dir pipelines/flink_pipelines
  #}

  {% if layer %}
    {% set cmd = 'python3 dbt_flink_deploy.py --layer ' ~ layer %}
  {% else %}
    {% set cmd = 'python3 dbt_flink_deploy.py --all' %}
  {% endif %}

  {{ log("", info=True) }}
  {{ log("=" * 80, info=True) }}
  {{ log("Flink deploy via dbt: run in a shell (dbt macros cannot call the Confluent API):", info=True) }}
  {{ log("  cd pipelines/flink_pipelines", info=True) }}
  {{ log("  python3 generate_flink_models.py   # if inventory.json changed", info=True) }}
  {{ log("  " ~ cmd, info=True) }}
  {{ log("=" * 80, info=True) }}
  {{ log("", info=True) }}

{% endmacro %}
