"""Device scenario simulator: one-shot patterns (stop motor, pressure oscillate, flow rate down)."""

import logging
import time

from backend.producer import init_producer, produce_device_metric
from backend.schema import DeviceMetricsValue
from backend.simulation import emit_telemetry_record

logger = logging.getLogger(__name__)

SOFTWARE_VERSION = "1.2.0"
BASE_PRESSURE = 10.0
BASE_FLOW_RATE = 2.5
BASE_MOTOR_SPEED = 3200.0


def _patient_id_from_device(device_id: str) -> str:
    if device_id.startswith("DEV-"):
        return device_id[4:]
    return device_id


def _produce_and_emit(rec: DeviceMetricsValue) -> None:
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


def _emit_three_metrics(
    device_id: str,
    patient_id: str,
    ts_ms: int,
    pressure: float,
    flow_rate: float,
    motor_speed: float,
) -> None:
    for name, val in [
        ("Pressure", pressure),
        ("FlowRate", flow_rate),
        ("MotorSpeed", motor_speed),
    ]:
        rec = DeviceMetricsValue(
            device_id, patient_id, ts_ms, name, val, SOFTWARE_VERSION
        )
        _produce_and_emit(rec)


def run_stop_motor(device_id: str) -> None:
    """Produce a short sequence: motor to 0, pressure/flow at baseline or zero."""
    patient_id = _patient_id_from_device(device_id)
    init_producer()
    ts_ms = int(time.time() * 1000)
    # One tick: motor 0, pressure and flow at baseline (or zero)
    _emit_three_metrics(
        device_id, patient_id, ts_ms, BASE_PRESSURE, BASE_FLOW_RATE, 0.0
    )
    logger.info("Stop motor scenario sent for device %s", device_id)


def run_pressure_oscillate(device_id: str) -> None:
    """Produce a short sequence of Pressure up then down (e.g. 8 -> 12 -> 16 -> 12 -> 8)."""
    patient_id = _patient_id_from_device(device_id)
    init_producer()
    steps = [8.0, 12.0, 16.0, 12.0, 8.0]
    for i, pressure in enumerate(steps):
        ts_ms = int(time.time() * 1000) + i
        _emit_three_metrics(
            device_id, patient_id, ts_ms, pressure, BASE_FLOW_RATE, BASE_MOTOR_SPEED
        )
        if i < len(steps) - 1:
            time.sleep(0.5)
    logger.info("Pressure oscillate scenario sent for device %s", device_id)


def run_flow_rate_down(device_id: str) -> None:
    """Produce a short sequence of FlowRate trending down (e.g. 2.5 -> 2.0 -> 1.0 -> 0.5)."""
    patient_id = _patient_id_from_device(device_id)
    init_producer()
    steps = [2.5, 2.0, 1.0, 0.5]
    for i, flow_rate in enumerate(steps):
        ts_ms = int(time.time() * 1000) + i
        _emit_three_metrics(
            device_id, patient_id, ts_ms, BASE_PRESSURE, flow_rate, BASE_MOTOR_SPEED
        )
        if i < len(steps) - 1:
            time.sleep(0.5)
    logger.info("Flow rate down scenario sent for device %s", device_id)
