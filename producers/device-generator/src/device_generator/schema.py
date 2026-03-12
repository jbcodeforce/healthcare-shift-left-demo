"""Avro schema for device-metrics value (matches Flink table)."""

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
