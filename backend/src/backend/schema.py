"""Avro schema for device-metrics value (matches Flink table)."""

from typing import Any


DEVICE_METRICS_VALUE_SCHEMA = """
{
  "type": "record",
  "name": "_flink_dev_device_metrics_value",
  "namespace": "org.apache.flink.avro.generated.record",
  "fields": [
    {"name": "device_id", "type": "string"},
    {"name": "patient_id", "type": "string"},
    {"name": "ts", "type": "long"},
    {"name": "metric_name", "type": "string"},
    {"name": "metric_value", "type": "double"},
    {"name": "software_version", "type": ["null", "string"], "default": null}
  ]
}
"""


class DeviceMetricsValue(object):
    def __init__(
        self,
        device_id: str,
        patient_id: str,
        ts: int,
        metric_name: str,
        metric_value: float,
        software_version: str | None = None,
    ):
        self.device_id = device_id
        self.patient_id = patient_id
        self.ts = ts
        self.metric_name = metric_name
        self.metric_value = metric_value
        self.software_version = software_version


# Legacy simulator used RPM-scale values under "MotorSpeed". All Kafka telemetry now uses FlowLevel on [0, 300].
_MOTOR_SPEED_RPM_REF = 3500.0
_FLOW_LEVEL_MAX = 300.0


def normalize_device_metric(record: DeviceMetricsValue) -> DeviceMetricsValue:
    """Map legacy MotorSpeed to FlowLevel (0–300) for Kafka and UI. Idempotent for other names."""
    name = (record.metric_name or "").strip()
    if name.casefold() != "motorspeed":
        return record
    rpm = float(record.metric_value)
    flow_level = min(_FLOW_LEVEL_MAX, max(0.0, rpm * (_FLOW_LEVEL_MAX / _MOTOR_SPEED_RPM_REF)))
    return DeviceMetricsValue(
        record.device_id,
        record.patient_id,
        record.ts,
        "FlowLevel",
        flow_level,
        record.software_version,
    )


class DeviceMetricsKey(object):
    def __init__(self, device_id: str):
        self.device_id = device_id


def device_metrics_value_to_avro(device_metrics: DeviceMetricsValue, ctx) -> dict:
    return dict[str, str | int | float | None](
        device_id=device_metrics.device_id,
        patient_id=device_metrics.patient_id,
        ts=device_metrics.ts,
        metric_name=device_metrics.metric_name,
        metric_value=device_metrics.metric_value,
        software_version=device_metrics.software_version,
    )


def device_metrics_key_to_dict(device_metrics_key: DeviceMetricsKey, ctxy) -> dict:
    return dict[str, str](device_id=device_metrics_key.device_id)
