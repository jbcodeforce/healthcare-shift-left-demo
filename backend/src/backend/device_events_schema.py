"""Avro schemas and serializers for BBH-style device lifecycle events and dimension upserts."""

from typing import Any


DEVICE_EVENTS_KEY_SCHEMA = """
{
  "type": "record",
  "name": "_flink_dev_device_events_key",
  "namespace": "org.apache.flink.avro.generated.record",
  "fields": [
    {"name": "event_id", "type": "string"}
  ]
}
"""


DEVICE_EVENTS_VALUE_SCHEMA = """
{
  "type": "record",
  "name": "_flink_dev_device_events_value",
  "namespace": "org.apache.flink.avro.generated.record",
  "fields": [
    {"name": "event_id", "type": "string"},
    {"name": "device_id", "type": "string"},
    {"name": "patient_id", "type": "string"},
    {"name": "event_type", "type": "string"},
    {"name": "lng", "type": ["null", "double"], "default": null},
    {"name": "lat", "type": ["null", "double"], "default": null},
    {"name": "battery_level", "type": ["null", "int"], "default": null},
    {"name": "plugged", "type": ["null", "boolean"], "default": null},
    {"name": "hw_model", "type": ["null", "string"], "default": null},
    {"name": "sw_version", "type": ["null", "string"], "default": null},
    {"name": "event_ts", "type": "long"}
  ]
}
"""


class DeviceEventValue:
    """One device lifecycle event for hc_raw_device_events."""

    def __init__(
        self,
        event_id: str,
        device_id: str,
        patient_id: str,
        event_type: str,
        event_ts: int,
        lng: float | None = None,
        lat: float | None = None,
        battery_level: int | None = None,
        plugged: bool | None = None,
        hw_model: str | None = None,
        sw_version: str | None = None,
    ):
        self.event_id = event_id
        self.device_id = device_id
        self.patient_id = patient_id
        self.event_type = event_type
        self.event_ts = event_ts
        self.lng = lng
        self.lat = lat
        self.battery_level = battery_level
        self.plugged = plugged
        self.hw_model = hw_model
        self.sw_version = sw_version


class DeviceEventKey:
    def __init__(self, event_id: str):
        self.event_id = event_id


def device_event_key_to_dict(key: DeviceEventKey, _ctx) -> dict[str, str]:
    return {"event_id": key.event_id}


def device_event_value_to_avro(value: DeviceEventValue, _ctx) -> dict[str, Any]:
    return {
        "event_id": value.event_id,
        "device_id": value.device_id,
        "patient_id": value.patient_id,
        "event_type": value.event_type,
        "lng": value.lng,
        "lat": value.lat,
        "battery_level": value.battery_level,
        "plugged": value.plugged,
        "hw_model": value.hw_model,
        "sw_version": value.sw_version,
        "event_ts": value.event_ts,
    }


DEVICE_ASSIGNMENTS_KEY_SCHEMA = """
{
  "type": "record",
  "name": "_flink_dev_device_assignments_key",
  "namespace": "org.apache.flink.avro.generated.record",
  "fields": [{"name": "assignment_id", "type": "string"}]
}
"""


DEVICE_ASSIGNMENTS_VALUE_SCHEMA = """
{
  "type": "record",
  "name": "_flink_dev_device_assignments_value",
  "namespace": "org.apache.flink.avro.generated.record",
  "fields": [
    {"name": "assignment_id", "type": "string"},
    {"name": "device_id", "type": "string"},
    {"name": "patient_id", "type": "string"},
    {"name": "assigned_at", "type": "long"},
    {"name": "active", "type": "boolean"}
  ]
}
"""


class DeviceAssignmentValue:
    def __init__(
        self,
        assignment_id: str,
        device_id: str,
        patient_id: str,
        assigned_at: int,
        active: bool,
    ):
        self.assignment_id = assignment_id
        self.device_id = device_id
        self.patient_id = patient_id
        self.assigned_at = assigned_at
        self.active = active


class DeviceAssignmentKey:
    def __init__(self, assignment_id: str):
        self.assignment_id = assignment_id


def device_assignment_key_to_dict(key: DeviceAssignmentKey, _ctx) -> dict[str, str]:
    return {"assignment_id": key.assignment_id}


def device_assignment_value_to_avro(value: DeviceAssignmentValue, _ctx) -> dict[str, Any]:
    return {
        "assignment_id": value.assignment_id,
        "device_id": value.device_id,
        "patient_id": value.patient_id,
        "assigned_at": value.assigned_at,
        "active": value.active,
    }


CARE_AREAS_KEY_SCHEMA = """
{
  "type": "record",
  "name": "_flink_dev_care_areas_key",
  "namespace": "org.apache.flink.avro.generated.record",
  "fields": [{"name": "area_id", "type": "string"}]
}
"""


CARE_AREAS_VALUE_SCHEMA = """
{
  "type": "record",
  "name": "_flink_dev_care_areas_value",
  "namespace": "org.apache.flink.avro.generated.record",
  "fields": [
    {"name": "area_id", "type": "string"},
    {"name": "patient_id", "type": "string"},
    {"name": "center_lat", "type": "double"},
    {"name": "center_lng", "type": "double"},
    {"name": "radius_m", "type": "double"}
  ]
}
"""


class CareAreaValue:
    def __init__(
        self,
        area_id: str,
        patient_id: str,
        center_lat: float,
        center_lng: float,
        radius_m: float,
    ):
        self.area_id = area_id
        self.patient_id = patient_id
        self.center_lat = center_lat
        self.center_lng = center_lng
        self.radius_m = radius_m


class CareAreaKey:
    def __init__(self, area_id: str):
        self.area_id = area_id


def care_area_key_to_dict(key: CareAreaKey, _ctx) -> dict[str, str]:
    return {"area_id": key.area_id}


def care_area_value_to_avro(value: CareAreaValue, _ctx) -> dict[str, Any]:
    return {
        "area_id": value.area_id,
        "patient_id": value.patient_id,
        "center_lat": value.center_lat,
        "center_lng": value.center_lng,
        "radius_m": value.radius_m,
    }


UPDATE_ALLOWLIST_KEY_SCHEMA = """
{
  "type": "record",
  "name": "_flink_dev_update_allowlist_key",
  "namespace": "org.apache.flink.avro.generated.record",
  "fields": [{"name": "device_id", "type": "string"}]
}
"""


UPDATE_ALLOWLIST_VALUE_SCHEMA = """
{
  "type": "record",
  "name": "_flink_dev_update_allowlist_value",
  "namespace": "org.apache.flink.avro.generated.record",
  "fields": [
    {"name": "device_id", "type": "string"},
    {"name": "target_sw_version", "type": "string"},
    {"name": "update_enabled", "type": "boolean"}
  ]
}
"""


class UpdateAllowlistValue:
    def __init__(self, device_id: str, target_sw_version: str, update_enabled: bool):
        self.device_id = device_id
        self.target_sw_version = target_sw_version
        self.update_enabled = update_enabled


class UpdateAllowlistKey:
    def __init__(self, device_id: str):
        self.device_id = device_id


def update_allowlist_key_to_dict(key: UpdateAllowlistKey, _ctx) -> dict[str, str]:
    return {"device_id": key.device_id}


def update_allowlist_value_to_avro(value: UpdateAllowlistValue, _ctx) -> dict[str, Any]:
    return {
        "device_id": value.device_id,
        "target_sw_version": value.target_sw_version,
        "update_enabled": value.update_enabled,
    }
