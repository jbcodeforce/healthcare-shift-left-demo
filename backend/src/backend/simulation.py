"""Device telemetry simulation: generates records matching device-metrics schema."""

import logging
import queue
import random
import threading
import time
from typing import Any

from backend.config import get_settings
from backend.producer import init_producer, produce_device_metric
from backend.schema import DeviceMetricsValue

logger = logging.getLogger(__name__)

SimulationType = str  # "all" | "single"

_simulation_running = False
_simulation_thread: threading.Thread | None = None
_simulation_patient_id: str | None = None
_simulation_type: SimulationType = "all"
_telemetry_sink: queue.Queue[dict[str, Any]] | None = None


def set_telemetry_sink(sink: "queue.Queue[dict[str, Any]] | None") -> None:
    """Register a queue to receive a copy of each telemetry record (for SSE etc.)."""
    global _telemetry_sink
    _telemetry_sink = sink


def _emit_telemetry(rec: dict[str, Any]) -> None:
    if _telemetry_sink is None:
        return
    try:
        _telemetry_sink.put_nowait(rec)
    except queue.Full:
        pass


def _device_id(patient_id: str) -> str:
    return f"DEV-{patient_id}"


def _patient_ids(n: int) -> list[str]:
    return [f"P{i:03d}" for i in range(1, n + 1)]


def _base_metrics() -> list[tuple[str, float, float]]:
    """(metric_name, base_value, jitter_range)."""
    return [
        ("Pressure", 10.0, 1.0),
        ("FlowRate", 2.5, 0.3),
        ("MotorSpeed", 3200.0, 150.0),
    ]


def _one_record(patient_id: str, ts_ms: int, software_version: str = "1.2.0") -> list[DeviceMetricsValue]:
    device_id = _device_id(patient_id)
    records = []
    for metric_name, base, jitter in _base_metrics():
        value = base + random.uniform(-jitter, jitter)
        records.append(
            DeviceMetricsValue(device_id, patient_id, ts_ms, metric_name, value, software_version)
        )
    return records


def _run_loop() -> None:
    global _simulation_running
    s = get_settings()
    interval = s.simulation_interval_seconds
    sim_type = _simulation_type
    patient_id_arg = _simulation_patient_id
    if sim_type == "single" and patient_id_arg:
        patient_ids = [patient_id_arg]
    else:
        patient_ids = _patient_ids(s.simulation_num_patients)
    try:
        init_producer()
    except Exception as e:
        logger.exception("Failed to init producer: %s", e)
        _simulation_running = False
        return
    logger.info("Simulation started: type=%s, patients=%s, interval=%.1fs", sim_type, patient_ids, interval)
    while _simulation_running:
        ts_ms = int(time.time() * 1000)
        for pid in patient_ids:
            for rec in _one_record(pid, ts_ms):
                try:
                    produce_device_metric(rec)
                    _emit_telemetry(
                        {
                            "device_id": rec.device_id,
                            "patient_id": rec.patient_id,
                            "ts": rec.ts,
                            "metric_name": rec.metric_name,
                            "metric_value": rec.metric_value,
                            "software_version": rec.software_version,
                        }
                    )
                except Exception as e:
                    logger.warning("Produce failed: %s", e)
        time.sleep(interval)
    logger.info("Simulation stopped.")


def start_simulation(
    *,
    patient_id: str | None = None,
    simulation_type: SimulationType = "all",
) -> bool:
    """Start the device simulation in a background thread. Returns True if started."""
    global _simulation_running, _simulation_thread, _simulation_patient_id, _simulation_type
    if _simulation_running:
        return False
    _simulation_patient_id = patient_id
    _simulation_type = simulation_type
    _simulation_running = True
    _simulation_thread = threading.Thread(target=_run_loop, daemon=True)
    _simulation_thread.start()
    return True


def stop_simulation() -> bool:
    """Stop the device simulation. Returns True if it was running."""
    global _simulation_running
    if not _simulation_running:
        return False
    _simulation_running = False
    if _simulation_thread is not None:
        _simulation_thread.join(timeout=5.0)
    return True


def is_simulation_running() -> bool:
    return _simulation_running
