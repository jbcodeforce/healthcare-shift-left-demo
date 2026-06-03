"""Kafka Avro producers for device events and BBH dimension topics."""

import logging
from typing import Any, Callable

from confluent_kafka import SerializingProducer
from confluent_kafka.schema_registry.avro import AvroSerializer
from confluent_kafka.serialization import SerializationContext

from backend.config import get_settings
from backend.device_events_schema import (
    CARE_AREAS_KEY_SCHEMA,
    CARE_AREAS_VALUE_SCHEMA,
    DEVICE_ASSIGNMENTS_KEY_SCHEMA,
    DEVICE_ASSIGNMENTS_VALUE_SCHEMA,
    DEVICE_EVENTS_KEY_SCHEMA,
    DEVICE_EVENTS_VALUE_SCHEMA,
    UPDATE_ALLOWLIST_KEY_SCHEMA,
    UPDATE_ALLOWLIST_VALUE_SCHEMA,
    CareAreaKey,
    CareAreaValue,
    DeviceAssignmentKey,
    DeviceAssignmentValue,
    DeviceEventKey,
    DeviceEventValue,
    UpdateAllowlistKey,
    UpdateAllowlistValue,
    care_area_key_to_dict,
    care_area_value_to_avro,
    device_assignment_key_to_dict,
    device_assignment_value_to_avro,
    device_event_key_to_dict,
    device_event_value_to_avro,
    update_allowlist_key_to_dict,
    update_allowlist_value_to_avro,
)
from backend.producer import _get_schema_from_registry, _make_subject_name_strategy
from backend.schema_registry_client import get_schema_registry_client

logger = logging.getLogger(__name__)

_producers: dict[str, SerializingProducer] = {}


def _topic_producer(
    topic: str,
    key_schema_str: str,
    value_schema_str: str,
    key_to_dict: Callable,
    value_to_dict: Callable,
) -> SerializingProducer:
    if topic in _producers:
        return _producers[topic]
    s = get_settings()
    if not s.kafka_bootstrap_servers:
        raise ValueError("KAFKA_BOOTSTRAP_SERVERS is required")
    registry = get_schema_registry_client(s)
    key_subject = f":{s.schema_subject_prefix}:{topic}-key"
    value_subject = f":{s.schema_subject_prefix}:{topic}-value"
    key_reg, key_schema = _get_schema_from_registry(key_subject)
    value_reg, value_schema = _get_schema_from_registry(value_subject)
    subject_strategy = _make_subject_name_strategy(s.schema_subject_prefix)
    key_serializer = AvroSerializer(
        schema_registry_client=registry,
        schema_str=key_schema,
        to_dict=key_to_dict,
        conf={
            "auto.register.schemas": False,
            "use.schema.id": key_reg.schema_id,
            "use.latest.version": True,
            "subject.name.strategy": subject_strategy,
        },
    )
    value_serializer = AvroSerializer(
        schema_registry_client=registry,
        schema_str=value_schema,
        to_dict=value_to_dict,
        conf={
            "auto.register.schemas": False,
            "use.schema.id": value_reg.schema_id,
            "use.latest.version": True,
            "subject.name.strategy": subject_strategy,
        },
    )
    producer_conf: dict[str, Any] = {
        "bootstrap.servers": s.kafka_bootstrap_servers,
        "security.protocol": s.kafka_security_protocol,
        "sasl.mechanisms": s.kafka_sasl_mechanism,
        "sasl.username": s.kafka_sasl_username,
        "sasl.password": s.kafka_sasl_password,
        "key.serializer": key_serializer,
        "value.serializer": value_serializer,
    }
    producer = SerializingProducer(producer_conf)
    _producers[topic] = producer
    return producer


def _delivery_report(err, msg) -> None:
    if err is not None:
        logger.warning("Delivery failed for %s: %s", msg.key(), err)


def produce_device_event(record: DeviceEventValue) -> None:
    """Produce one device lifecycle event to hc_raw_device_events."""
    s = get_settings()
    topic = s.kafka_device_events_topic
    producer = _topic_producer(
        topic,
        DEVICE_EVENTS_KEY_SCHEMA,
        DEVICE_EVENTS_VALUE_SCHEMA,
        device_event_key_to_dict,
        device_event_value_to_avro,
    )
    producer.produce(topic, key=DeviceEventKey(record.event_id), value=record, on_delivery=_delivery_report)
    producer.poll(0)


def produce_device_assignment(record: DeviceAssignmentValue) -> None:
    s = get_settings()
    topic = s.kafka_device_assignments_topic
    producer = _topic_producer(
        topic,
        DEVICE_ASSIGNMENTS_KEY_SCHEMA,
        DEVICE_ASSIGNMENTS_VALUE_SCHEMA,
        device_assignment_key_to_dict,
        device_assignment_value_to_avro,
    )
    producer.produce(topic, key=DeviceAssignmentKey(record.assignment_id), value=record, on_delivery=_delivery_report)
    producer.poll(0)


def produce_care_area(record: CareAreaValue) -> None:
    s = get_settings()
    topic = s.kafka_care_areas_topic
    producer = _topic_producer(
        topic,
        CARE_AREAS_KEY_SCHEMA,
        CARE_AREAS_VALUE_SCHEMA,
        care_area_key_to_dict,
        care_area_value_to_avro,
    )
    producer.produce(topic, key=CareAreaKey(record.area_id), value=record, on_delivery=_delivery_report)
    producer.poll(0)


def produce_update_allowlist(record: UpdateAllowlistValue) -> None:
    s = get_settings()
    topic = s.kafka_update_allowlist_topic
    producer = _topic_producer(
        topic,
        UPDATE_ALLOWLIST_KEY_SCHEMA,
        UPDATE_ALLOWLIST_VALUE_SCHEMA,
        update_allowlist_key_to_dict,
        update_allowlist_value_to_avro,
    )
    producer.produce(topic, key=UpdateAllowlistKey(record.device_id), value=record, on_delivery=_delivery_report)
    producer.poll(0)


def flush_device_event_producers(timeout: float = 10.0) -> None:
    for producer in _producers.values():
        producer.flush(timeout)
