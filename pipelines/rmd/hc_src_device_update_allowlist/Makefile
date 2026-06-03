include ../../../common.mk

TABLE_NAME=hc_src_device_update_allowlist
SCRIPT_PRE_KEBAB=dev-usw2-rmd
SCRIPT_POST_KEBAB=$(subst _,-,$(TABLE_NAME))

DDL_STATEMENT=$(SCRIPT_PRE_KEBAB)-ddl-$(SCRIPT_POST_KEBAB)
DDL_SCRIPT=./sql-scripts/ddl.$(TABLE_NAME).sql

create_hc_src_device_update_allowlist: create_flink_ddl

create_flink_ddl:
	$(call create_flink_statement, $(DDL_STATEMENT), $(DDL_SCRIPT))
	$(call delete_flink_statement, $(DDL_STATEMENT))

delete_flink_ddl:
	$(call delete_flink_statement, $(DDL_STATEMENT))
