"""Pytest fixtures and skip conditions for device-generator tests."""

import os

import pytest

# Fail fast with a clear message if the project env is not active (e.g. pytest run without uv)
try:
    import pydantic_settings  # noqa: F401
except ModuleNotFoundError:
    raise ModuleNotFoundError(
        "pydantic_settings not found. Run pytest with the project environment: "
        "from producers/device-generator run `uv sync --extra dev` then `uv run pytest tests/ -v`"
    ) from None

from fastapi.testclient import TestClient

from device_generator.main import app


def _kafka_configured() -> bool:
    return bool(os.environ.get("KAFKA_BOOTSTRAP_SERVERS") or os.environ.get("BOOTSTRAP_SERVERS"))


requires_kafka = pytest.mark.skipif(
    not _kafka_configured(),
    reason="KAFKA_BOOTSTRAP_SERVERS (and Confluent credentials) required for integration tests",
)


@pytest.fixture
def client() -> TestClient:
    """FastAPI test client."""
    return TestClient(app)
