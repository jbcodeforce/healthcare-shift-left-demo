"""Unit tests for demo data helpers."""

from backend.data import get_devices

_LIFECYCLE_KEYS = ("softwareVersion", "latitude", "longitude", "batteryLevel", "plugged")


def test_get_devices_includes_lifecycle_fields() -> None:
    devices = get_devices()
    assert len(devices) >= 5
    for d in devices:
        for key in _LIFECYCLE_KEYS:
            assert key in d, f"missing {key} on {d.get('device_id')}"
        assert d["softwareVersion"] in ("1.2.0", "2.0.0")
        assert 33 <= d["batteryLevel"] <= 90
        assert isinstance(d["plugged"], bool)
        assert -90 <= d["latitude"] <= 90
        assert -180 <= d["longitude"] <= 180


def test_demo_patients_have_distinct_chicago_locations() -> None:
    by_id = {d["patientId"]: d for d in get_devices()}
    p001, p002 = by_id["P001"], by_id["P002"]
    assert p001["latitude"] != p002["latitude"] or p001["longitude"] != p002["longitude"]
    assert p001["sw_version"] == "1.2.0"
    assert p002["sw_version"] == "2.0.0"
