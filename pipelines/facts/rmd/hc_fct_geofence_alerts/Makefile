include ../../../common.mk

TABLE_NAME=hc_fct_geofence_alerts
SCRIPT_PRE_KEBAB=dev-usw2-rmd
SCRIPT_POST_KEBAB=$(subst _,-,$(TABLE_NAME))

DDL_STATEMENT=$(SCRIPT_PRE_KEBAB)-ddl-$(SCRIPT_POST_KEBAB)
DDL_SCRIPT=./sql-scripts/ddl.$(TABLE_NAME).sql
DML_STATEMENT=$(SCRIPT_PRE_KEBAB)-dml-$(SCRIPT_POST_KEBAB)
DML_SCRIPT=./sql-scripts/dml.$(TABLE_NAME).sql
DML_PROPERTIES=./sql-scripts/dml.$(TABLE_NAME).properties

create_hc_fct_geofence_alerts: create_flink_ddl create_flink_dml

create_flink_ddl:
	$(call create_flink_statement, $(DDL_STATEMENT), $(DDL_SCRIPT))
	$(call delete_flink_statement, $(DDL_STATEMENT))

create_flink_dml:
	$(call create_flink_statement, $(DML_STATEMENT), $(DML_SCRIPT), $(DML_PROPERTIES))

delete_flink_statements: delete_flink_ddl delete_flink_dml

delete_flink_dml:
	$(call delete_flink_statement, $(DML_STATEMENT))

delete_flink_ddl:
	$(call delete_flink_statement, $(DDL_STATEMENT))
