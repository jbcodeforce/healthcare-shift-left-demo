"""Integration tests: send one record to remote Kafka, then start and stop simulation."""

import time

import pytest
<<<<<<<< HEAD:backend/tests/integration/test_kafka_and_simulation.py
from backend.producer import flush_producer, init_producer, produce_device_metric, _get_schema_registry_client
from backend.simulation import is_simulation_running, stop_simulation
from backend.schema import DeviceMetricsValue
========
from device_generator.producer import flush_producer, init_producer, produce_device_metric, _get_schema_registry_client
from device_generator.simulation import is_simulation_running, stop_simulation
from device_generator.schema import DeviceMetricsValue
>>>>>>>> 0e0addfe9fd8f56eee2a9ed8472e160859466c6c:producers/device-generator/tests/integration/test_kafka_and_simulation.py
from ..conftest import requires_kafka

def test_get_schema_subjects(client) -> None:
    """Get the schema subjects from the Schema Registry."""
    init_producer()
    registry = _get_schema_registry_client()
    subjects = registry.get_subjects(subject_prefix=".flink_dev")
    print(subjects)
    assert subjects is not None
    assert len(subjects) > 0
    assert ":.flink-dev:device_metrics-value" in subjects
    assert ":.flink-dev:device_metrics-key" in subjects

def _one_sample_record() -> DeviceMetricsValue:
    """Single device-metric record matching the Avro schema."""
    return DeviceMetricsValue(device_id="device_1", patient_id="patient_1", ts=1715404800000, metric_name="metric_1", metric_value=1.0, software_version="1.0.0")


@requires_kafka
def test_send_one_record_to_kafka(client) -> None:
    """Produce one record to remote Kafka and flush."""
    init_producer()
    produce_device_metric(_one_sample_record())
    remaining = flush_producer(timeout=15.0)
    assert remaining == 0, f"Producer flush left {remaining} messages"


@requires_kafka
def test_start_and_stop_simulation(client) -> None:
    """Start simulation via API, let it run briefly, then stop via API."""
    # Ensure simulation is stopped before we start (e.g. from a previous test)
    if is_simulation_running():
        stop_simulation()
        time.sleep(0.5)

    start_resp = client.post("/simulation/start", json={"simulation_type": "all"})
    assert start_resp.status_code == 200, start_resp.text
    assert start_resp.json()["status"] == "started"

    # Let a few batches be produced (interval is typically 2s)
    time.sleep(2.5)

    stop_resp = client.post("/simulation/stop")
    assert stop_resp.status_code == 200, stop_resp.text
    assert stop_resp.json()["status"] == "stopped"

    time.sleep(0.5)
    assert not is_simulation_running()


