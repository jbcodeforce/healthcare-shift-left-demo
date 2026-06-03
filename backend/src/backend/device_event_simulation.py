"""Simulate BBH-style device events and seed dimension topics for Flink demos."""

import logging
import time
import uuid
from typing import Literal

from backend.config import get_settings
from backend.data import get_devices, get_patients
from backend.device_events_producer import (
    flush_device_event_producers,
    produce_care_area,
    produce_device_assignment,
    produce_device_event,
    produce_update_allowlist,
)
from backend.device_events_schema import (
    CareAreaValue,
    DeviceAssignmentValue,
    DeviceEventValue,
    UpdateAllowlistValue,
)
from backend.simulation import get_story_time_ms

logger = logging.getLogger(__name__)

EventType = Literal["BUTTON_PRESSED", "POWER_STATUS", "GPS"]
HW_MODEL = "RMD-100"
SW_VERSION = "1.2.0"

# Chicago-area demo coordinates (inside / outside geofence)
_GEOFENCE_CENTERS = {
    "P001": (41.8781, -87.6298),
    "P002": (41.9214, -87.6513),
    "P003": (41.9484, -87.6553),
    "P004": (41.7948, -87.5901),
    "P005": (41.8566, -87.6244),
}
_INSIDE_OFFSET = (0.0005, 0.0005)
_OUTSIDE_OFFSET = (0.05, 0.05)

_button_press_counts: dict[str, int] = {}


def _event_ts_ms() -> int:
    story = get_story_time_ms()
    if story is not None:
        return story
    return int(time.time() * 1000)


def _new_event_id(prefix: str) -> str:
    return f"{prefix}-{uuid.uuid4().hex[:12]}"


def seed_bbh_dimensions() -> None:
    """Publish assignment, geofence, and OTA allowlist dimension rows to Kafka."""
    s = get_settings()
    if not s.kafka_bootstrap_servers:
        logger.debug("Kafka not configured; skipping BBH dimension seed")
        return
    now_ms = int(time.time() * 1000)
    for patient in get_patients():
        pid = patient["patientId"]
        device_id = f"DEV-{pid}"
        produce_device_assignment(
            DeviceAssignmentValue(
                assignment_id=f"ASSIGN-{pid}",
                device_id=device_id,
                patient_id=pid,
                assigned_at=now_ms,
                active=True,
            )
        )
        center = _GEOFENCE_CENTERS.get(pid, (41.8781, -87.6298))
        produce_care_area(
            CareAreaValue(
                area_id=f"AREA-{pid}",
                patient_id=pid,
                center_lat=center[0],
                center_lng=center[1],
                radius_m=500.0,
            )
        )
    for device in get_devices()[:3]:
        produce_update_allowlist(
            UpdateAllowlistValue(
                device_id=device["device_id"],
                target_sw_version="2.0.0",
                update_enabled=True,
            )
        )
    flush_device_event_producers()
    logger.info("Seeded BBH dimension topics (assignments, care areas, allowlist)")


def emit_device_event(
    device_id: str,
    patient_id: str,
    event_type: EventType,
    *,
    lat: float | None = None,
    lng: float | None = None,
    battery_level: int | None = None,
    plugged: bool | None = None,
) -> DeviceEventValue:
    """Build and produce one device event."""
    ts_ms = _event_ts_ms()
    rec = DeviceEventValue(
        event_id=_new_event_id(event_type.lower()[:3]),
        device_id=device_id,
        patient_id=patient_id,
        event_type=event_type,
        event_ts=ts_ms,
        lat=lat,
        lng=lng,
        battery_level=battery_level,
        plugged=plugged,
        hw_model=HW_MODEL,
        sw_version=SW_VERSION,
    )
    produce_device_event(rec)
    return rec


def simulate_button_press(device_id: str, patient_id: str) -> dict:
    """Emit BUTTON_PRESSED; tracks count per device for first vs repeat press demos."""
    count = _button_press_counts.get(device_id, 0) + 1
    _button_press_counts[device_id] = count
    rec = emit_device_event(device_id, patient_id, "BUTTON_PRESSED")
    flush_device_event_producers()
    return {"event_id": rec.event_id, "press_count": count, "device_id": device_id}


def simulate_power_status(
    device_id: str,
    patient_id: str,
    *,
    battery_level: int = 75,
    plugged: bool = True,
) -> dict:
    rec = emit_device_event(
        device_id,
        patient_id,
        "POWER_STATUS",
        battery_level=battery_level,
        plugged=plugged,
    )
    flush_device_event_producers()
    return {"event_id": rec.event_id, "battery_level": battery_level, "plugged": plugged}


def simulate_gps(
    device_id: str,
    patient_id: str,
    *,
    inside_geofence: bool = True,
) -> dict:
    center = _GEOFENCE_CENTERS.get(patient_id, (40.4406, -79.9959))
    offset = _INSIDE_OFFSET if inside_geofence else _OUTSIDE_OFFSET
    lat = center[0] + offset[0]
    lng = center[1] + offset[1]
    rec = emit_device_event(device_id, patient_id, "GPS", lat=lat, lng=lng)
    flush_device_event_producers()
    return {"event_id": rec.event_id, "lat": lat, "lng": lng, "inside_geofence": inside_geofence}


def simulate_bbh_scenarios(device_id: str | None = None) -> list[dict]:
    """Run button, power, and GPS scenarios for one or all demo devices."""
    devices = get_devices()
    if device_id:
        devices = [d for d in devices if d["device_id"] == device_id]
    results = []
    for d in devices:
        pid = d["patientId"]
        dev = d["device_id"]
        results.append(simulate_button_press(dev, pid))
        results.append(simulate_power_status(dev, pid, battery_level=80, plugged=True))
        results.append(simulate_gps(dev, pid, inside_geofence=True))
        results.append(simulate_gps(dev, pid, inside_geofence=False))
    return results
