#!/bin/bash
# 1) Grant REPLICATION so Debezium can use the replication slot.
# 2) Create publication for prescriptions so the connector does not need CREATE PUBLICATION
#    (only superusers can create publications; demo user is not superuser).
set -e
psql -v ON_ERROR_STOP=1 --dbname "${POSTGRES_DB:-healthcare}" <<-EOSQL
ALTER USER "${POSTGRES_USER:-demo}" WITH REPLICATION;
-- Publication must exist before the connector starts; table created in 01-prescriptions-schema.sql
CREATE PUBLICATION IF NOT EXISTS debezium_healthcare FOR TABLE public.prescriptions;
EOSQL
