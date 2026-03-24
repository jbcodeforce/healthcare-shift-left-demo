"""Device telemetry simulation: generates records matching device-metrics schema."""

import logging
import queue
import random
import threading
import time
from collections import deque
from datetime import timedelta
from typing import Any

from backend.config import get_settings
from backend.producer import init_producer, produce_device_metric
from backend.schema import DeviceMetricsValue, normalize_device_metric

logger = logging.getLogger(__name__)

# Keep last N telemetry records sent to Kafka for metrics API (5–10 devices × 3 metrics × several ticks).
TELEMETRY_CACHE_MAXLEN = 200

SimulationType = str  # "all" | "single"

_simulation_running = False
_simulation_thread: threading.Thread | None = None
_simulation_patient_id: str | None = None
_simulation_type: SimulationType = "all"
_telemetry_sink: queue.Queue[dict[str, Any]] | None = None
_telemetry_cache: deque[dict[str, Any]] = deque(maxlen=TELEMETRY_CACHE_MAXLEN)

# Last simulated event time (epoch ms) from the background loop; scenarios reuse this when sim is running.
_story_clock_lock = threading.Lock()
_story_time_ms: int | None = None


def get_story_time_ms() -> int | None:
    """Epoch ms of the latest record emitted by the device simulation, or None if sim is not running."""
    with _story_clock_lock:
        return _story_time_ms


def _set_story_time_ms(ts_ms: int) -> None:
    global _story_time_ms
    with _story_clock_lock:
        _story_time_ms = ts_ms


def _clear_story_time_ms() -> None:
    global _story_time_ms
    with _story_clock_lock:
        _story_time_ms = None


def set_telemetry_sink(sink: "queue.Queue[dict[str, Any]] | None") -> None:
    """Register a queue to receive a copy of each telemetry record (for SSE etc.)."""
    global _telemetry_sink
    _telemetry_sink = sink


def _emit_telemetry(rec: dict[str, Any]) -> None:
    _telemetry_cache.append(rec)
    if _telemetry_sink is None:
        return
    try:
        _telemetry_sink.put_nowait(rec)
    except queue.Full:
        pass


def emit_telemetry_record(rec: dict[str, Any]) -> None:
    """Append a telemetry record to the cache and SSE sink (for simulator scenarios)."""
    _emit_telemetry(rec)


def get_cached_telemetry() -> list[dict[str, Any]]:
    """Return the last N telemetry records sent to Kafka (for metrics API)."""
    return list(_telemetry_cache)


def _device_id(patient_id: str) -> str:
    return f"DEV-{patient_id}"


def _patient_ids(n: int) -> list[str]:
    return [f"P{i:03d}" for i in range(1, n + 1)]


def _base_metrics() -> list[tuple[str, float, float]]:
    """(metric_name, base_value, jitter_range)."""
    return [
        ("Pressure", 10.0, 1.0),
        ("FlowRate", 2.5, 0.3),
        ("FlowLevel", 150.0, 100.0),  # clamped to [0, 300] in _one_record
    ]


def _interruptible_sleep(seconds: float) -> None:
    """Sleep up to `seconds` wall time, waking early if simulation stops."""
    remaining = max(0.0, seconds)
    while remaining > 0 and _simulation_running:
        step = min(0.25, remaining)
        time.sleep(step)
        remaining -= step


def _one_record(patient_id: str, ts_ms: int, software_version: str = "1.2.0") -> list[DeviceMetricsValue]:
    device_id = _device_id(patient_id)
    records = []
    for metric_name, base, jitter in _base_metrics():
        value = base + random.uniform(-jitter, jitter)
        if metric_name == "FlowLevel":
            value = max(0.0, min(130.0, value))
        records.append(
            DeviceMetricsValue(device_id, patient_id, ts_ms, metric_name, value, software_version)
        )
    return records


def _run_loop() -> None:
    try:
        _run_loop_inner()
    finally:
        _clear_story_time_ms()


def _run_loop_inner() -> None:
    global _simulation_running
    s = get_settings()
    sim_step_sec = s.simulation_interval_seconds
    records_per_sec = s.simulation_records_per_second
    pace_seconds = (1.0 / records_per_sec) if records_per_sec > 0 else 0.0
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
    lookback = timedelta(days=s.simulation_backfill_days)
    sim_step_ms = int(sim_step_sec * 1000)
    sim_ts_ms = int((time.time() - lookback.total_seconds()) * 1000)
    logger.info(
        "Simulation started: type=%s, patients=%s, sim_step=%.1fs, records_per_s=%s, sim_ts_start_ms=%s",
        sim_type,
        patient_ids,
        sim_step_sec,
        records_per_sec,
        sim_ts_ms,
    )
    while _simulation_running:
        ts_ms = sim_ts_ms
        for pid in patient_ids:
            if not _simulation_running:
                break
            for rec in _one_record(pid, ts_ms):
                if not _simulation_running:
                    break
                try:
                    rec = normalize_device_metric(rec)
                    produce_device_metric(rec)
                    _set_story_time_ms(rec.ts)
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
                _interruptible_sleep(pace_seconds)
            if not _simulation_running:
                break
        sim_ts_ms += sim_step_ms
        if not _simulation_running:
            break
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
