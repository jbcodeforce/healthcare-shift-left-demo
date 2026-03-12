"""Confluent Kafka producer with Avro value serialization for Confluent Cloud."""

import logging
from typing import Any

from confluent_kafka import Producer
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serialization import MessageField, SerializationContext

from device_generator.config import get_settings
from device_generator.schema import DEVICE_METRICS_VALUE_SCHEMA

logger = logging.getLogger(__name__)

_producer: Producer | None = None
_avro_serializer: AvroSerializer | None = None
_topic: str = ""


def _get_schema_registry_client() -> SchemaRegistryClient:
    s = get_settings()
    conf: dict[str, str] = {"url": s.schema_registry_url}
    if s.schema_registry_basic_auth_user_info:
        conf["basic.auth.user.info"] = s.schema_registry_basic_auth_user_info
    return SchemaRegistryClient(conf)


def init_producer() -> None:
    """Initialize Kafka producer and Avro serializer. Idempotent."""
    global _producer, _avro_serializer, _topic
    if _producer is not None:
        return
    s = get_settings()
    print(s)
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
    _avro_serializer = AvroSerializer(registry, DEVICE_METRICS_VALUE_SCHEMA)
    _topic = s.kafka_topic
    logger.info("Kafka producer initialized for topic=%s", _topic)


def produce_device_metric(record: dict[str, Any]) -> None:
    """Serialize and produce one device-metric record to Kafka. Call init_producer() first."""
    if _producer is None or _avro_serializer is None:
        raise RuntimeError("Producer not initialized; call init_producer() first")
    payload = _avro_serializer(
        record,
        SerializationContext(_topic, MessageField.VALUE),
    )
    _producer.produce(_topic, value=payload, key=record.get("device_id", "").encode("utf-8"))
    _producer.poll(0)


def flush_producer(timeout: float = 10.0) -> int:
    """Flush outstanding messages. Returns number of messages remaining (0 = success)."""
    if _producer is None:
        return 0
    return _producer.flush(timeout=timeout)
