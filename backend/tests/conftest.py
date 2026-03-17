"""Pytest fixtures and skip conditions for device-generator tests."""

import os

import pytest

from fastapi.testclient import TestClient

from backend.main import app
from backend.config import get_settings


def _kafka_configured() -> bool:
    return bool(get_settings().kafka_bootstrap_servers)


def _database_configured() -> bool:
    return bool(get_settings().database_url)


requires_kafka = pytest.mark.skipif(
    not _kafka_configured(),
    reason="KAFKA_BOOTSTRAP_SERVERS (and Confluent credentials) required for integration tests",
)

requires_database = pytest.mark.skipif(
    not _database_configured(),
    reason="DATABASE_URL required for prescriptions integration tests",
)


@pytest.fixture
def client() -> TestClient:
    """FastAPI test client."""
    return TestClient(app)
