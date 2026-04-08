"""Integration: consume hc_fct_telemetry_1h with Avro + Schema Registry."""

import pytest
from confluent_kafka import KafkaError
from confluent_kafka.error import ConsumeError

from backend.config import get_settings
from backend.telemetry_1h_consumer import create_telemetry_1h_consumer

from ..conftest import requires_kafka


@requires_kafka
def test_telemetry_1h_consumer_subscribe_and_poll() -> None:
    """Subscribe and poll without error; if a record exists, value matches fact shape."""
    s = get_settings()
    if not s.schema_registry_url:
        pytest.skip("SCHEMA_REGISTRY_URL required for Avro deserialization")
    consumer = create_telemetry_1h_consumer(s)
    try:
        try:
            msg = consumer.poll(timeout=5.0)
        except ConsumeError as e:
            if e.args and e.args[0].code() == KafkaError.UNKNOWN_TOPIC_OR_PART:
                pytest.skip("Topic hc_fct_telemetry_1h not present on this cluster")
            raise
        if msg is None:
            return
        if msg.error():
            if msg.error().code() == KafkaError._PARTITION_EOF:
                return
            pytest.fail(str(msg.error()))
        val = msg.value()
        print(val)
        if val is not None:
            assert isinstance(val, dict)
            expected_any = (
                "window_start",
                "device_id",
                "avg_value",
                "metric_name",
                "patient_id",
            )
            assert any(k in val for k in expected_any), f"Unexpected payload keys: {val.keys()}"
    finally:
        consumer.close()
