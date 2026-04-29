output "flink_statements_ddl_raw" {
  description = "Raw layer DDL statement IDs"
  value = var.deploy_flink_statements ? {
    for k, v in confluent_flink_statement.ddl_raw : k => {
      id   = v.id
      name = v.statement_name
    }
  } : {}
}

output "flink_statements_ddl_rmd" {
  description = "RMD layer DDL statement IDs"
  value = var.deploy_flink_statements ? {
    for k, v in confluent_flink_statement.ddl_rmd : k => {
      id   = v.id
      name = v.statement_name
    }
  } : {}
}

output "flink_statements_dml_raw" {
  description = "Raw layer DML statement IDs"
  value = var.deploy_flink_statements ? {
    for k, v in confluent_flink_statement.dml_raw : k => {
      id   = v.id
      name = v.statement_name
    }
  } : {}
}

output "flink_statements_dml_rmd" {
  description = "RMD layer DML statement IDs"
  value = var.deploy_flink_statements ? {
    for k, v in confluent_flink_statement.dml_rmd : k => {
      id   = v.id
      name = v.statement_name
    }
  } : {}
}
