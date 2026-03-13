#!/usr/bin/env bash
# Idempotent: create the Debezium PostgreSQL connector if missing, or update config if it exists.
# Usage: run from repo root with backend/.env (or set POSTGRES_USER, POSTGRES_PASSWORD).
#   ./connect/register-connector.sh
#   CONNECT_URL=http://localhost:8083 ./connect/register-connector.sh

set -e
CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONNECTOR_JSON="${SCRIPT_DIR}/debezium-postgres.json"
CONNECTOR_NAME="debezium-postgres-healthcare"

# Optional: load backend/.env for POSTGRES_USER, POSTGRES_PASSWORD
if [ -f "${SCRIPT_DIR}/../backend/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/../backend/.env"
  set +a
fi

POSTGRES_USER="${POSTGRES_USER:-demo}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-demo}"

# Substitute placeholders and build payload
PAYLOAD=$(sed \
  -e "s/__POSTGRES_USER__/${POSTGRES_USER}/g" \
  -e "s/__POSTGRES_PASSWORD__/${POSTGRES_PASSWORD}/g" \
  "${CONNECTOR_JSON}")

# Wait for Connect REST API
echo "Waiting for Kafka Connect at ${CONNECT_URL}..."
until curl -sf "${CONNECT_URL}/connectors" > /dev/null 2>&1; do
  echo "  Connect not ready, retrying in 5s..."
  sleep 5
done
echo "Connect is up."

# Create or update
EXISTING=$(curl -sf "${CONNECT_URL}/connectors/${CONNECTOR_NAME}" 2>/dev/null || true)
if [ -z "${EXISTING}" ]; then
  echo "Creating connector ${CONNECTOR_NAME}..."
  curl -sf -X POST -H "Content-Type: application/json" \
    --data "${PAYLOAD}" \
    "${CONNECT_URL}/connectors"
  echo ""
  echo "Connector ${CONNECTOR_NAME} created."
else
  echo "Connector ${CONNECTOR_NAME} already exists."
  if command -v jq >/dev/null 2>&1; then
    echo "Updating config..."
    BODY=$(echo "${PAYLOAD}" | jq -c '.config')
    curl -sf -X PUT -H "Content-Type: application/json" \
      --data "${BODY}" \
      "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/config"
    echo ""
    echo "Connector ${CONNECTOR_NAME} config updated."
  else
    echo "Install jq to update config; skipping update."
  fi
fi

echo "Check status: curl -s ${CONNECT_URL}/connectors/${CONNECTOR_NAME}/status | jq ."
