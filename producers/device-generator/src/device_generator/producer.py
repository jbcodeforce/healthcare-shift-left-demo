"""Confluent Kafka producer with Avro value serialization for Confluent Cloud."""

import logging
from typing import Any

from confluent_kafka import Producer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serialization import MessageField, SerializationContext

from device_generator.config import get_settings
from device_generator.schema import device_metrics_key_to_dict, device_metrics_to_dict, DeviceMetricsValue
from device_generator.schema import DeviceMetricsKey

logger = logging.getLogger(__name__)

_producer: Producer | None = None
_avro_key_serializer: AvroSerializer | None = None
_avro_serializer: AvroSerializer | None = None
_topic: str = ""


def _get_schema_registry_client() -> SchemaRegistryClient:
    s = get_settings()
    conf: dict[str, str] = {"url": s.schema_registry_url}
    if s.schema_registry_basic_auth_user_info:
        conf["basic.auth.user.info"] = s.schema_registry_basic_auth_user_info
    return SchemaRegistryClient(conf)


def _get_schema_from_registry(subject: str) -> str:
    """Fetch the latest schema for the subject from Schema Registry (no new schema pushed)."""
    registry = _get_schema_registry_client()
    registered = registry.get_latest_version(subject)
    return registered.schema.schema_str


def init_producer() -> None:
    """Initialize Kafka producer and Avro key/value serializers. Idempotent.
    Uses existing key and value schemas from Schema Registry (subjects: <topic>-key, <topic>-value).
    """
    global _producer, _avro_key_serializer, _avro_serializer, _topic
    if _producer is not None:
        return
    s = get_settings()
    if not s.kafka_bootstrap_servers:
        raise ValueError("KAFKA_BOOTSTRAP_SERVERS is required")
    producer_conf: dict[str, Any] = {
        "bootstrap.servers": s.kafka_bootstrap_servers,
        "security.protocol": s.kafka_security_protocol,
        "sasl.mechanisms": s.kafka_sasl_mechanism,
        "sasl.username": s.kafka_sasl_username,
        "sasl.password": s.kafka_sasl_password,
    }
    _producer = Producer(producer_conf)
    registry = _get_schema_registry_client()
    topic = s.kafka_topic
    key_schema_str = _get_schema_from_registry(f"{topic}-key")
    value_schema_str = _get_schema_from_registry(f"{topic}-value")
    print(key_schema_str)
    print(value_schema_str)
    _avro_key_serializer = AvroSerializer(registry, key_schema_str, device_metrics_key_to_dict)
    _avro_serializer = AvroSerializer(registry, value_schema_str, device_metrics_to_dict)
    _topic = topic
    logger.info("Kafka producer initialized for topic=%s (key and value schema from registry)", _topic)


def produce_device_metric(record: DeviceMetricsValue) -> None:
    """Serialize and produce one device-metric record to Kafka. Call init_producer() first.
    Key is Avro-serialized as {\"device_id\": \"<device_id>\"}; value is the full record.
    """
    if _producer is None or _avro_serializer is None or _avro_key_serializer is None:
        raise RuntimeError("Producer not initialized; call init_producer() first")
    key_payload = _avro_key_serializer(
        DeviceMetricsKey(record.device_id), 
        SerializationContext(_topic, MessageField.KEY)
    )
    value_payload = _avro_serializer(
        record,
        SerializationContext(_topic, MessageField.VALUE)
    )
    print(key_payload)
    print(value_payload)
    _producer.produce(_topic, key=key_payload, value=value_payload)
    _producer.poll(0)


def flush_producer(timeout: float = 10.0) -> int:
    """Flush outstanding messages. Returns number of messages remaining (0 = success)."""
    if _producer is None:
        return 0
    return _producer.flush(timeout=timeout)
