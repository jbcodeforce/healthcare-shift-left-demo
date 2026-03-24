"""Device scenario simulator: one-shot patterns (stop motor, pressure oscillate, flow rate down)."""

import logging
import time

from backend.producer import init_producer, produce_device_metric
from backend.schema import DeviceMetricsValue, normalize_device_metric
from backend.simulation import emit_telemetry_record, get_story_time_ms

logger = logging.getLogger(__name__)

SOFTWARE_VERSION = "1.2.0"
BASE_PRESSURE = 10.0
BASE_FLOW_RATE = 2.5
BASE_FLOW_LEVEL = 150.0  # telemetry FlowLevel range [0, 300]


def _scenario_base_ts_ms() -> int:
    """Align scenario timestamps with the running simulation timeline, else wall clock."""
    story = get_story_time_ms()
    if story is not None:
        return story
    return int(time.time() * 1000)


def _patient_id_from_device(device_id: str) -> str:
    if device_id.startswith("DEV-"):
        return device_id[4:]
    return device_id


def _produce_and_emit(rec: DeviceMetricsValue) -> None:
    rec = normalize_device_metric(rec)
    produce_device_metric(rec)
    emit_telemetry_record(
        {
            "device_id": rec.device_id,
            "patient_id": rec.patient_id,
            "ts": rec.ts,
            "metric_name": rec.metric_name,
            "metric_value": rec.metric_value,
            "software_version": rec.software_version,
        }
    )


def _emit_the_three_metrics(
    device_id: str,
    patient_id: str,
    ts_ms: int,
    pressure: float,
    flow_rate: float,
    flow_level: float,
) -> None:
    flow_level = max(0.0, min(300.0, flow_level))

    for name, val in [
        ("Pressure", pressure),
        ("FlowRate", flow_rate),
        ("FlowLevel", flow_level),
    ]:
        rec = DeviceMetricsValue(
            device_id, patient_id, ts_ms, name, val, SOFTWARE_VERSION
        )
        _produce_and_emit(rec)


def run_flow_level_down(device_id: str) -> None:
    """Produce a short sequence: flow_level to 0, pressure/flow at baseline or zero."""
    patient_id = _patient_id_from_device(device_id)
    init_producer()
    base_ts = _scenario_base_ts_ms()
    steps = [60, 50, 40, 30, 20, 15, 10, 0]
    for i, pressure in enumerate(steps):
        ts_ms = base_ts + i
        _emit_the_three_metrics(
            device_id, patient_id, ts_ms, pressure, BASE_FLOW_RATE, BASE_FLOW_LEVEL
        )
        if i < len(steps) - 1:
            time.sleep(0.5)
    logger.info("Flow level down scenario sent for device %s", device_id)


def run_pressure_oscillate(device_id: str) -> None:
    """Produce a short sequence of Pressure up then down (e.g. 8 -> 12 -> 16 -> 12 -> 8)."""
    patient_id = _patient_id_from_device(device_id)
    init_producer()
    base_ts = _scenario_base_ts_ms()
    steps = [12.0, 16.0, 22.0, 21.0, 18.0, 15.0, 22.0, 19.0, 16.0, 13.0, 10.0]
    for i, pressure in enumerate(steps):
        ts_ms = base_ts + i
        _emit_the_three_metrics(
            device_id, patient_id, ts_ms, pressure, BASE_FLOW_RATE, BASE_FLOW_LEVEL
        )
        if i < len(steps) - 1:
            time.sleep(0.5)
    logger.info("Pressure oscillate scenario sent for device %s", device_id)


def run_flow_rate_down(device_id: str) -> None:
    """Produce a short sequence of FlowRate trending down (e.g. 2.5 -> 2.0 -> 1.0 -> 0.5)."""
    patient_id = _patient_id_from_device(device_id)
    init_producer()
    base_ts = _scenario_base_ts_ms()
    steps = [2.5, 2.0, 1.0, 0.5, 0.0, 0.7, 1.4, 2.1, 1.3,1.0, 0.7, 0.4, 0.1]
    for i, flow_rate in enumerate(steps):
        ts_ms = base_ts + i
        _emit_the_three_metrics(
            device_id, patient_id, ts_ms, BASE_PRESSURE, flow_rate, BASE_FLOW_LEVEL
        )
        if i < len(steps) - 1:
            time.sleep(0.5)
    logger.info("Flow rate down scenario sent for device %s", device_id)
