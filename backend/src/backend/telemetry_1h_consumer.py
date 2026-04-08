"""Consume hc_fct_telemetry_1h from Confluent Cloud: Avro key/value via Schema Registry."""

from __future__ import annotations

import logging
import signal
import threading
from collections.abc import Callable
from typing import Any

from confluent_kafka import DeserializingConsumer, KafkaError

from backend.config import Settings, get_settings
from backend.schema_registry_client import get_schema_registry_client

logger = logging.getLogger(__name__)

OnMessage = Callable[[Any, Any, str, int, int], None]


def log_consumed_record(key: Any, value: Any, topic: str, partition: int, offset: int) -> None:
    """Log one consumed record at DEBUG (avoid INFO spam at high throughput)."""
    logger.debug(
        "telemetry_1h %s[%s]@%s key=%s value=%s",
        topic,
        partition,
        offset,
        key,
        value,
    )


def create_telemetry_1h_consumer(settings: Settings | None = None) -> DeserializingConsumer:
    """Create a DeserializingConsumer subscribed to kafka_consumer_topic (default hc_fct_telemetry_1h)."""
    if settings is None:
        settings = get_settings()
    if not settings.kafka_bootstrap_servers:
        raise ValueError("KAFKA_BOOTSTRAP_SERVERS is required for the telemetry consumer")
    if not settings.schema_registry_url:
        raise ValueError("SCHEMA_REGISTRY_URL is required for Avro deserialization")

    from confluent_kafka.schema_registry.avro import AvroDeserializer

    registry = get_schema_registry_client(settings)
    key_deserializer = AvroDeserializer(registry)
    value_deserializer = AvroDeserializer(registry)

    conf: dict[str, Any] = {
        "bootstrap.servers": settings.kafka_bootstrap_servers,
        "security.protocol": settings.kafka_security_protocol,
        "sasl.mechanisms": settings.kafka_sasl_mechanism,
        "sasl.username": settings.kafka_sasl_username,
        "sasl.password": settings.kafka_sasl_password,
        "group.id": settings.kafka_consumer_group_id,
        "auto.offset.reset": settings.kafka_consumer_auto_offset_reset,
        "key.deserializer": key_deserializer,
        "value.deserializer": value_deserializer,
    }

    consumer = DeserializingConsumer(conf)
    consumer.subscribe([settings.kafka_consumer_topic])
    logger.info("Subscribed to Kafka topic %s", settings.kafka_consumer_topic)
    return consumer


def run_poll_loop(
    consumer: DeserializingConsumer,
    *,
    stop_event: threading.Event,
    poll_timeout: float = 1.0,
    on_message: OnMessage | None = None,
) -> None:
    """Poll until stop_event is set; deserialize errors and broker errors are logged."""
    handler = on_message or log_consumed_record
    try:
        while not stop_event.is_set():
            msg = consumer.poll(poll_timeout)
            if stop_event.is_set():
                break
            if msg is None:
                continue
            if msg.error():
                err = msg.error()
                if err.code() == KafkaError._PARTITION_EOF:
                    continue
                logger.error("Consumer error: %s", err)
                continue
            try:
                handler(msg.key(), msg.value(), msg.topic(), msg.partition(), msg.offset())
            except Exception:
                logger.exception("on_message failed for %s[%s]@%s", msg.topic(), msg.partition(), msg.offset())
    finally:
        consumer.close()
        logger.info("Telemetry 1h consumer closed")


def main() -> None:
    """Run consumer until SIGINT/SIGTERM (CLI: uv run python -m backend.telemetry_1h_consumer)."""
    logging.basicConfig(level=logging.INFO)
    stop = threading.Event()

    def handle_signal(_signum: int, _frame: Any) -> None:
        stop.set()

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    settings = get_settings()
    consumer = create_telemetry_1h_consumer(settings)
    run_poll_loop(consumer, stop_event=stop)


if __name__ == "__main__":
    main()
