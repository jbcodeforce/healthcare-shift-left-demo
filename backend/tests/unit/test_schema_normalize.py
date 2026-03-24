"""normalize_device_metric: legacy MotorSpeed → FlowLevel for Kafka."""

from backend.schema import DeviceMetricsValue, normalize_device_metric


def test_motor_speed_maps_to_flow_level() -> None:
    rec = DeviceMetricsValue("DEV-P001", "P001", 1, "MotorSpeed", 3500.0, "1.2.0")
    out = normalize_device_metric(rec)
    assert out.metric_name == "FlowLevel"
    assert abs(out.metric_value - 300.0) < 0.01


def test_flow_level_unchanged() -> None:
    rec = DeviceMetricsValue("DEV-P001", "P001", 1, "FlowLevel", 150.0, "1.2.0")
    out = normalize_device_metric(rec)
    assert out is rec or (out.metric_name == "FlowLevel" and out.metric_value == 150.0)


def test_motorspeed_case_insensitive() -> None:
    rec = DeviceMetricsValue("DEV-P001", "P001", 1, "MOTORSPEED", 0.0, None)
    out = normalize_device_metric(rec)
    assert out.metric_name == "FlowLevel"
    assert out.metric_value == 0.0
