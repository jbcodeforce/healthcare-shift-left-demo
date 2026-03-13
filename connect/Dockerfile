# Kafka Connect with Debezium PostgreSQL connector for Confluent Cloud.
# Confluent image includes Avro + Schema Registry converters; we add Debezium.
FROM confluentinc/cp-kafka-connect:7.8.0
ENV CONNECT_PLUGIN_PATH="/usr/share/java,/usr/share/confluent-hub-components"
USER root
RUN confluent-hub install debezium/debezium-connector-postgresql:2.5.4 --no-prompt
USER appuser
