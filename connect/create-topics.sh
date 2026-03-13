#!/usr/bin/env bash
# Pre-create Kafka topics required by the Debezium connector to avoid UNKNOWN_TOPIC_OR_PARTITION.
# Use with Confluent Cloud CLI (ccloud). Run from repo root.
#   ./connect/create-topics.sh
# Or with explicit topic prefix: DEBEZIUM_TOPIC_PREFIX=healthcare ./connect/create-topics.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "${SCRIPT_DIR}/../backend/.env" ]; then
  set -a
  # shellcheck source=/dev/null
  source "${SCRIPT_DIR}/../backend/.env"
  set +a
fi

PREFIX="${DEBEZIUM_TOPIC_PREFIX:-healthcare}"
# Data topic: {topic.prefix}.{schema}.{table} for table.include.list=public.prescriptions
DATA_TOPIC="${PREFIX}.public.prescriptions"
PARTITIONS="${DEBEZIUM_TOPIC_PARTITIONS:-1}"

if ! command -v ccloud &>/dev/null; then
  echo "Confluent Cloud CLI (ccloud) not found. Install it or create the topic manually:"
  echo "  Topic: ${DATA_TOPIC}"
  echo "  Partitions: ${PARTITIONS}"
  exit 1
fi

echo "Creating topic ${DATA_TOPIC} (partitions=${PARTITIONS})..."
ccloud kafka topic create "${DATA_TOPIC}" --partitions "${PARTITIONS}" 2>/dev/null || true
echo "Done. Restart the Debezium connector if it was failing with UNKNOWN_TOPIC_OR_PARTITION."
