"""Shared Confluent Schema Registry client for producer and consumers."""

from __future__ import annotations

from typing import TYPE_CHECKING

from confluent_kafka.schema_registry import SchemaRegistryClient

if TYPE_CHECKING:
    from backend.config import Settings


def get_schema_registry_client(settings: Settings | None = None) -> SchemaRegistryClient:
    """Build a SchemaRegistryClient from settings (URL + optional basic auth)."""
    if settings is None:
        from backend.config import get_settings

        settings = get_settings()
    conf: dict[str, str] = {"url": settings.schema_registry_url}
    if settings.schema_registry_basic_auth_user_info:
        conf["basic.auth.user.info"] = settings.schema_registry_basic_auth_user_info
    return SchemaRegistryClient(conf)
