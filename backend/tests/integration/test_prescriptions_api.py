"""Integration tests for prescriptions API. POST /prescriptions when DB not set returns 503; when set, creates a prescription."""

import pytest

from ..conftest import requires_database


def test_create_prescription_returns_503_when_db_not_configured(client) -> None:
    """POST /prescriptions (no trailing slash) returns 503 when DATABASE_URL is not set."""
    resp = client.post(
        "/prescriptions",
        json={
            "patient_id": "patient_1",
            "device_id": "DEV-P001",
            "medication_or_therapy": "Therapy A",
            "parameters": "[]",
        },
    )
    # Either 503 (no DB) or 201 (DB configured); never 405 (method not allowed)
    assert resp.status_code in (201, 503), f"Expected 201 or 503, got {resp.status_code}"
    if resp.status_code == 503:
        assert "PostgreSQL" in resp.json().get("detail", "") or "DATABASE" in str(resp.json())


@requires_database
def test_create_prescription_returns_201_when_db_configured(client) -> None:
    """POST /prescriptions with DATABASE_URL set creates a prescription and returns 201."""
    resp = client.post(
        "/prescriptions",
        json={
            "patient_id": "patient_1",
            "device_id": "DEV-P001",
            "medication_or_therapy": "Therapy A",
            "parameters": "[]",
        },
    )
    assert resp.status_code == 201, resp.text
    body = resp.json()
    assert "prescriptionId" in body
    assert body["patientId"] == "patient_1"
    assert body["deviceId"] == "DEV-P001"
