#!/bin/bash
# Grant REPLICATION to the app user so Debezium can create logical replication slots.
set -e
psql -v ON_ERROR_STOP=1 --dbname "${POSTGRES_DB:-healthcare}" <<-EOSQL
ALTER USER "${POSTGRES_USER:-demo}" WITH REPLICATION;
EOSQL
