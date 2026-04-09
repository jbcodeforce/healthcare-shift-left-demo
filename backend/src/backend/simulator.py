"""Device scenario simulator: one-shot patterns (stop motor, pressure oscillate, flow rate down)."""

import logging
import time

from backend.producer import init_producer, produce_device_metric
from backend.schema import DeviceMetricsValue, normalize_device_metric
from backend.simulation import emit_telemetry_record, get_last_snapshot_for_device, get_story_time_ms

logger = logging.getLogger(__name__)

SOFTWARE_VERSION = "1.2.0"
BASE_PRESSURE = 10.0
BASE_FLOW_RATE = 2.5
BASE_FLOW_LEVEL = 150.0  # telemetry FlowLevel range [0, 300]


def _baseline_metrics(device_id: str) -> tuple[float, float, float]:
    """Pressure, flow rate, flow level to hold when a scenario only varies one metric."""
    snap = get_last_snapshot_for_device(device_id)
    p = float(snap.get("Pressure", BASE_PRESSURE))
    fr = float(snap.get("FlowRate", BASE_FLOW_RATE))
    fl = float(snap.get("FlowLevel", BASE_FLOW_LEVEL))
    fl = max(0.0, min(300.0, fl))
    return p, fr, fl


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
    """Produce a short sequence: flow_level ramps down to 0; pressure and flow rate stay steady."""
    patient_id = _patient_id_from_device(device_id)
    init_producer()
    hold_p, hold_fr, _ = _baseline_metrics(device_id)
    base_ts = _scenario_base_ts_ms()
    flow_level_steps = [60, 50, 40, 30, 20, 15, 10, 0]
    for i, flow_level in enumerate(flow_level_steps):
        ts_ms = base_ts + i
        _emit_the_three_metrics(
            device_id, patient_id, ts_ms, hold_p, hold_fr, flow_level
        )
        if i < len(flow_level_steps) - 1:
            time.sleep(0.5)
    logger.info("Flow level down scenario sent for device %s", device_id)


def run_pressure_oscillate(device_id: str) -> None:
    """Vary pressure only; flow rate and flow level stay at the latest cached values (else baseline)."""
    patient_id = _patient_id_from_device(device_id)
    init_producer()
    _, hold_fr, hold_fl = _baseline_metrics(device_id)
    base_ts = _scenario_base_ts_ms()
    pressure_steps = [12.0, 16.0, 22.0, 21.0, 18.0, 15.0, 22.0, 19.0, 16.0, 13.0, 10.0]
    for i, pressure in enumerate(pressure_steps):
        ts_ms = base_ts + i
        _emit_the_three_metrics(
            device_id, patient_id, ts_ms, pressure, hold_fr, hold_fl
        )
        if i < len(pressure_steps) - 1:
            time.sleep(0.5)
    logger.info("Pressure oscillate scenario sent for device %s", device_id)


def run_flow_rate_down(device_id: str) -> None:
    """Vary flow rate only; pressure and flow level stay at the latest cached values (else baseline)."""
    patient_id = _patient_id_from_device(device_id)
    init_producer()
    hold_p, _, hold_fl = _baseline_metrics(device_id)
    base_ts = _scenario_base_ts_ms()
    flow_rate_steps = [2.5, 2.0, 1.0, 0.5, 0.0, 0.7, 1.4, 2.1, 1.3, 1.0, 0.7, 0.4, 0.1]
    for i, flow_rate in enumerate(flow_rate_steps):
        ts_ms = base_ts + i
        _emit_the_three_metrics(
            device_id, patient_id, ts_ms, hold_p, flow_rate, hold_fl
        )
        if i < len(flow_rate_steps) - 1:
            time.sleep(0.5)
    logger.info("Flow rate down scenario sent for device %s", device_id)
