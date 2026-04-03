{% macro deploy_flink_pipelines(layer=none) %}
  {#
    dbt run-operation to deploy Flink pipelines
    Usage:
      dbt run-operation deploy_flink_pipelines
      dbt run-operation deploy_flink_pipelines --args '{layer: raw}'
      dbt run-operation deploy_flink_pipelines --args '{layer: rmd}'
  #}

  {% set python_script = project_root() ~ '/deploy_flink.py' %}

  {% if layer %}
    {% set cmd = 'python3 ' ~ python_script ~ ' --layer ' ~ layer %}
  {% else %}
    {% set cmd = 'python3 ' ~ python_script ~ ' --all' %}
  {% endif %}

  {{ log("Executing: " ~ cmd, info=True) }}

  {% set result = run_query("SELECT 1") %}

  {{ log("", info=True) }}
  {{ log("=" * 80, info=True) }}
  {{ log("To deploy Flink pipelines, run:", info=True) }}
  {{ log("  cd " ~ project_root(), info=True) }}
  {{ log("  " ~ cmd, info=True) }}
  {{ log("=" * 80, info=True) }}
  {{ log("", info=True) }}

{% endmacro %}


{% macro project_root() %}
  {# Get the project root directory #}
  {% set root = env_var('DBT_PROJECT_DIR', '/Users/quaziquader/git-repos/healthcare-shift-left-demo/pipelines/flink_pipelines') %}
  {{ return(root) }}
{% endmacro %}
