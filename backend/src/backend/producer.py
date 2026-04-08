"""Confluent Kafka producer with Avro value serialization for Confluent Cloud."""

import logging
from typing import Any, Callable, Optional

from confluent_kafka import Producer, SerializingProducer
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serialization import SerializationContext

from backend.config import get_settings
from backend.schema_registry_client import get_schema_registry_client
from backend.schema import (
    DeviceMetricsKey,
    DeviceMetricsValue,
    device_metrics_key_to_dict,
    device_metrics_value_to_avro,
    normalize_device_metric,
)

logger = logging.getLogger(__name__)


def _make_subject_name_strategy(prefix: str) -> Callable[[Optional[SerializationContext], Optional[str]], Optional[str]]:
    """Subject name strategy that returns Confluent Cloud format: ':{prefix}:{topic}-{field}'."""

    def subject_name_strategy(ctx: Optional[SerializationContext], record_name: Optional[str]) -> Optional[str]:
        if ctx is None:
            raise ValueError("SerializationContext is required for subject name strategy.")
        return f":{prefix}:{ctx.topic}-{ctx.field}"

    return subject_name_strategy


_producer: Producer | None = None
_avro_key_serializer: AvroSerializer | None = None
_avro_value_serializer: AvroSerializer | None = None
_topic: str = ""


def _get_schema_from_registry(subject: str):
    """Fetch the latest schema for the subject from Schema Registry (no new schema pushed)."""
    registry = get_schema_registry_client()
    registered = registry.get_latest_version(subject)
    return registered, registered.schema


def init_producer() -> None:
    """Initialize Kafka producer and Avro key/value serializers. Idempotent."""
    global _producer, _avro_key_serializer, _avro_value_serializer, _topic
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
    registry = get_schema_registry_client(s)
    topic = s.kafka_topic
    key_subject = f":{s.schema_subject_prefix}:{topic}-key"
    value_subject = f":{s.schema_subject_prefix}:{topic}-value"
    key_reg, key_schema = _get_schema_from_registry(key_subject)
    value_reg, value_schema = _get_schema_from_registry(value_subject)
    subject_strategy = _make_subject_name_strategy(s.schema_subject_prefix)
    key_conf: dict[str, Any] = {
        "auto.register.schemas": False,
        "use.schema.id": key_reg.schema_id,
        "use.latest.version": True,
        "subject.name.strategy": subject_strategy,
    }
    value_conf: dict[str, Any] = {
        "auto.register.schemas": False,
        "use.schema.id": value_reg.schema_id,
        "use.latest.version": True,
        "subject.name.strategy": subject_strategy,
    }
    _avro_key_serializer = AvroSerializer(
        schema_registry_client=registry,
        schema_str=key_schema,
        to_dict=device_metrics_key_to_dict,
        conf=key_conf,
    )
    _avro_value_serializer = AvroSerializer(
        schema_registry_client=registry,
        schema_str=value_schema,
        to_dict=device_metrics_value_to_avro,
        conf=value_conf,
    )
    _topic = topic
    producer_conf["key.serializer"] = _avro_key_serializer
    producer_conf["value.serializer"] = _avro_value_serializer
    _producer = SerializingProducer(producer_conf)


def delivery_report(err, msg):
    if err is not None:
        logger.warning("Delivery failed for record %s: %s", msg.key(), err)
    else:
        logger.debug("Record %s produced to %s[%s] @ offset %s", msg.key(), msg.topic(), msg.partition(), msg.offset())


def produce_device_metric(record: DeviceMetricsValue) -> None:
    """Serialize and produce one device-metric record to Kafka. Call init_producer() first."""
    if _producer is None or _avro_value_serializer is None or _avro_key_serializer is None:
        raise RuntimeError("Producer not initialized; call init_producer() first")
    record = normalize_device_metric(record)
    key_obj = DeviceMetricsKey(record.device_id)
    _producer.produce(_topic, key=key_obj, value=record, on_delivery=delivery_report)
    _producer.poll(0)


def flush_producer(timeout: float = 10.0) -> int:
    """Flush outstanding messages. Returns number of messages remaining (0 = success)."""
    if _producer is None:
        return 0
    return _producer.flush(timeout=timeout)
