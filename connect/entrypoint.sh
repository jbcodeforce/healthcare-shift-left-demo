#!/bin/bash
# Optional: when SCHEMA_REGISTRY_CONTEXT is set, use Schema Registry URL with /contexts/<context>.
# Subject name prefix (:.flink-dev:topic-key): set via CONNECT_*_SUBJECT_NAME_PREFIX in docker-compose;
# also inject as JVM system property so PrefixTopicNameStrategy gets it even if converter config is not passed.
set -e
if [ -n "${SCHEMA_REGISTRY_CONTEXT}" ] && [ -n "${SCHEMA_REGISTRY_URL}" ]; then
  base="${SCHEMA_REGISTRY_URL%/}"
  # full_url="${base}/contexts/${SCHEMA_REGISTRY_CONTEXT}"
  export CONNECT_KEY_CONVERTER_SCHEMA_REGISTRY_URL="${base}"
  export CONNECT_VALUE_CONVERTER_SCHEMA_REGISTRY_URL="${base}"
fi
# Ensure custom subject strategy receives prefix (fallback if converter config keys are not passed through)
prefix="${SCHEMA_SUBJECT_PREFIX:-.flink-dev}"
if [ -n "${prefix}" ]; then
  export KAFKA_OPTS="${KAFKA_OPTS:-} -Dconnect.subject.name.prefix=${prefix}"
fi
exec /etc/confluent/docker/run "$@"
