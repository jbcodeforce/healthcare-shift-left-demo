# Build custom subject name strategy JAR (matches producer's ":{prefix}:{topic}-key" format)
FROM maven:3.9-eclipse-temurin-11 AS strategy-builder
WORKDIR /build
COPY subject-strategy/pom.xml /build/pom.xml
COPY subject-strategy/src /build/src
RUN mvn package -DskipTests -q -B

# Kafka Connect with Debezium PostgreSQL connector for Confluent Cloud.
# Confluent image includes Avro + Schema Registry converters; we add Debezium and custom subject strategy.
# The strategy JAR must be on the worker's main classpath so AvroConverter can load it (launch script
# uses CLASSPATH=/etc/kafka-connect/jars/*). Plugin-path classloaders are isolated and don't see this.
FROM confluentinc/cp-kafka-connect:7.8.0
ENV CONNECT_PLUGIN_PATH="/usr/share/java,/usr/share/confluent-hub-components"
USER root
RUN confluent-hub install debezium/debezium-connector-postgresql:2.5.4 --no-prompt
COPY --from=strategy-builder /build/target/subject-strategy-1.0.0.jar /etc/kafka-connect/jars/
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
USER appuser
ENTRYPOINT ["/entrypoint.sh"]
