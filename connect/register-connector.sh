#!/usr/bin/env bash
# Idempotent: create the Debezium PostgreSQL connector if missing, or update config if it exists.
# Uses the same env vars as docker-compose (backend/.env). See connect/README.md for the full list.
#
# Usage: run from repo root.
#   ./connect/register-connector.sh
#   CONNECT_URL=http://localhost:8083 ./connect/register-connector.sh
#   POSTGRES_HOST=postgres POSTGRES_DB=healthcare ./connect/register-connector.sh

set -e
CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONNECTOR_JSON="${SCRIPT_DIR}/debezium-postgres.json"

# Load backend/.env so we use the same vars as docker-compose and the connector config
if [ -f "${SCRIPT_DIR}/../backend/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/../backend/.env"
  set +a
fi

# Connector and Postgres settings (defaults match docker-compose and postgres service)
DEBEZIUM_CONNECTOR_NAME="${DEBEZIUM_CONNECTOR_NAME:-debezium-postgres-healthcare}"
POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_DB="${POSTGRES_DB:-healthcare}"
POSTGRES_USER="${POSTGRES_USER:-demo}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-demo}"
DEBEZIUM_TOPIC_PREFIX="${DEBEZIUM_TOPIC_PREFIX:-healthcare}"
TABLE_INCLUDE_LIST="${TABLE_INCLUDE_LIST:-public.prescriptions}"
# Replication slot name (must be unique per connector; used with publication debezium_healthcare)
SLOT_NAME="${DEBEZIUM_SLOT_NAME:-debezium_healthcare_slot}"

# Substitute placeholders in the JSON (use | for sed delimiter where value may contain /)
PAYLOAD=$(sed \
  -e "s|__CONNECTOR_NAME__|${DEBEZIUM_CONNECTOR_NAME}|g" \
  -e "s|__POSTGRES_HOST__|${POSTGRES_HOST}|g" \
  -e "s|__POSTGRES_PORT__|${POSTGRES_PORT}|g" \
  -e "s|__POSTGRES_DB__|${POSTGRES_DB}|g" \
  -e "s|__POSTGRES_USER__|${POSTGRES_USER}|g" \
  -e "s|__POSTGRES_PASSWORD__|${POSTGRES_PASSWORD}|g" \
  -e "s|__TOPIC_PREFIX__|${DEBEZIUM_TOPIC_PREFIX}|g" \
  -e "s|__TABLE_INCLUDE_LIST__|${TABLE_INCLUDE_LIST}|g" \
  -e "s|__SLOT_NAME__|${SLOT_NAME}|g" \
  "${CONNECTOR_JSON}")

# Wait for Connect REST API
echo "Waiting for Kafka Connect at ${CONNECT_URL}..."
until curl -sf "${CONNECT_URL}/connectors" > /dev/null 2>&1; do
  echo "  Connect not ready, retrying in 5s..."
  sleep 5
done
echo "Connect is up."

# Create or update
if [ -z "$(curl -sf "${CONNECT_URL}/connectors/${DEBEZIUM_CONNECTOR_NAME}" 2>/dev/null)" ]; then
  echo "Creating connector ${DEBEZIUM_CONNECTOR_NAME}..."
  curl -sf -X POST -H "Content-Type: application/json" \
    --data "${PAYLOAD}" \
    "${CONNECT_URL}/connectors"
  echo ""
  echo "Connector ${DEBEZIUM_CONNECTOR_NAME} created."
else
  echo "Connector ${DEBEZIUM_CONNECTOR_NAME} already exists."
  if command -v jq >/dev/null 2>&1; then
    echo "Updating config..."
    BODY=$(echo "${PAYLOAD}" | jq -c '.config')
    curl -sf -X PUT -H "Content-Type: application/json" \
      --data "${BODY}" \
      "${CONNECT_URL}/connectors/${DEBEZIUM_CONNECTOR_NAME}/config"
    echo ""
    echo "Connector ${DEBEZIUM_CONNECTOR_NAME} config updated."
  else
    echo "Install jq to update config; skipping update."
  fi
fi

echo "Check status: curl -s ${CONNECT_URL}/connectors/${DEBEZIUM_CONNECTOR_NAME}/status | jq ."
