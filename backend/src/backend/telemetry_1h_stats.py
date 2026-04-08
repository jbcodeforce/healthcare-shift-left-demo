"""In-process counters for hc_fct_telemetry_1h records consumed by the backend Kafka consumer."""

from __future__ import annotations

import threading
import time
from typing import Any

from backend.config import get_settings

_lock = threading.Lock()
_windows_received: int = 0
_total_readings_in_windows: int = 0
_by_device: dict[str, int] = {}
_by_metric: dict[str, int] = {}
_last_message_at: float | None = None


def record_consumed_message(key: Any, value: Any, topic: str, partition: int, offset: int) -> None:
    """Update aggregates for one deserialized Kafka message (called from consumer thread)."""
    global _windows_received, _total_readings_in_windows, _last_message_at
    with _lock:
        _windows_received += 1
        _last_message_at = time.time()
        if isinstance(value, dict):
            did = value.get("device_id")
            if did is not None:
                dk = str(did)
                _by_device[dk] = _by_device.get(dk, 0) + 1
            mn = value.get("metric_name")
            if mn is not None:
                mk = str(mn)
                _by_metric[mk] = _by_metric.get(mk, 0) + 1
            cr = value.get("count_reading")
            if cr is not None:
                try:
                    _total_readings_in_windows += int(cr)
                except (TypeError, ValueError):
                    pass
        elif key is not None and isinstance(key, dict):
            did = key.get("device_id")
            if did is not None:
                dk = str(did)
                _by_device[dk] = _by_device.get(dk, 0) + 1


def get_telemetry_1h_widget_payload() -> dict[str, Any]:
    """Snapshot for GET /analytics/telemetry-1h-counts (JSON-serializable)."""
    s = get_settings()
    with _lock:
        by_device = sorted(
            [{"device_id": k, "count": v} for k, v in _by_device.items()],
            key=lambda x: -x["count"],
        )[:25]
        by_metric = sorted(
            [{"metric_name": k, "count": v} for k, v in _by_metric.items()],
            key=lambda x: -x["count"],
        )[:25]
        last_iso = None
        if _last_message_at is not None:
            last_iso = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(_last_message_at))
        return {
            "consumer_enabled": s.kafka_consumer_enabled,
            "topic": s.kafka_consumer_topic,
            "windows_received": _windows_received,
            "total_readings_in_windows": _total_readings_in_windows,
            "by_device": by_device,
            "by_metric": by_metric,
            "last_message_at": last_iso,
        }
