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
  def __init__(self, device_id: str, patient_id: str, ts: int, metric_name: str, metric_value: float, software_version: str | None = None):
    self.device_id = device_id
    self.patient_id = patient_id
    self.ts = ts
    self.metric_name = metric_name
    self.metric_value = metric_value
    self.software_version = software_version

class DeviceMetricsKey(object):
  def __init__(self, device_id: str):
    self.device_id = device_id
  
def device_metrics_to_dict(device_metrics: DeviceMetricsValue, ctx) -> dict:
  return dict[str, str | int | float | None](
    device_id=device_metrics.device_id,
    patient_id=device_metrics.patient_id,
    ts=device_metrics.ts,
    metric_name=device_metrics.metric_name,
    metric_value=device_metrics.metric_value,
    software_version=device_metrics.software_version
  )

def device_metrics_key_to_dict(device_metrics_key: DeviceMetricsKey, ctxy) -> dict:
  return dict[str, str](
    device_id=device_metrics_key.device_id
  )