"""Analytics: query Parquet (and optionally Iceberg) tables via DuckDB for dashboard metrics."""

from __future__ import annotations

import logging
from pathlib import Path
from typing import Any

import duckdb

from backend.config import get_settings

logger = logging.getLogger(__name__)

_conn: duckdb.DuckDBPyConnection | None = None
_configured: bool | None = None


def _is_configured() -> bool:
    global _configured
    if _configured is not None:
        return _configured
    s = get_settings()
    has_s3 = bool(s.analytics_s3_bucket and s.analytics_s3_prefix)
    has_local = bool(s.analytics_local_path)
    _configured = has_s3 or has_local
    return _configured


def _get_conn() -> duckdb.DuckDBPyConnection:
    global _conn
    if _conn is not None:
        return _conn
    s = get_settings()
    _conn = duckdb.connect(":memory:")
    try:
        _conn.execute("INSTALL httpfs")
        _conn.execute("LOAD httpfs")
    except duckdb.Error as e:
        logger.warning("httpfs extension load failed: %s", e)
    try:
        _conn.execute("INSTALL iceberg")
        _conn.execute("LOAD iceberg")
    except duckdb.Error as e:
        logger.debug("iceberg extension load failed (optional): %s", e)
    if s.analytics_s3_bucket:
        if s.aws_access_key_id and s.aws_secret_access_key:
            try:
                _conn.execute(
                    "CREATE SECRET (TYPE s3, KEY_ID ?, SECRET ?, REGION ?)",
                    [s.aws_access_key_id, s.aws_secret_access_key, s.aws_region or "us-east-1"],
                )
            except duckdb.Error as e:
                logger.warning("S3 secret creation failed: %s", e)
        else:
            try:
                _conn.execute("CREATE SECRET (TYPE s3, PROVIDER credential_chain)")
            except duckdb.Error as e:
                logger.warning("S3 credential_chain failed: %s", e)
    return _conn


def _anomalies_path() -> str | None:
    s = get_settings()
    if s.analytics_s3_bucket and s.analytics_s3_prefix:
        base = f"s3://{s.analytics_s3_bucket}/{s.analytics_s3_prefix.rstrip('/')}"
        return f"{base}/anomalies.parquet"
    if s.analytics_local_path:
        p = Path(s.analytics_local_path).expanduser().resolve()
        single = p / "anomalies.parquet"
        if single.exists():
            return str(single)
        return str(p / "anomalies")
    return None


def _prescription_changes_path() -> str | None:
    s = get_settings()
    if s.analytics_s3_bucket and s.analytics_s3_prefix:
        base = f"s3://{s.analytics_s3_bucket}/{s.analytics_s3_prefix.rstrip('/')}"
        return f"{base}/prescription_changes.parquet"
    if s.analytics_local_path:
        p = Path(s.analytics_local_path).expanduser().resolve()
        single = p / "prescription_changes.parquet"
        if single.exists():
            return str(single)
        return str(p / "prescription_changes")
    return None


def _device_first_seen_path() -> str | None:
    s = get_settings()
    if s.analytics_s3_bucket and s.analytics_s3_prefix:
        base = f"s3://{s.analytics_s3_bucket}/{s.analytics_s3_prefix.rstrip('/')}"
        return f"{base}/device_first_seen.parquet"
    if s.analytics_local_path:
        p = Path(s.analytics_local_path).expanduser().resolve()
        single = p / "device_first_seen.parquet"
        if single.exists():
            return str(single)
        return str(p / "device_first_seen")
    return None


def get_anomalies_per_device() -> list[dict[str, Any]]:
    """Return count of anomalies grouped by device_id. Empty if not configured or table missing."""
    if not _is_configured():
        return []
    path = _anomalies_path()
    if not path:
        return []
    try:
        conn = _get_conn()
        rows = conn.execute(
            """
            SELECT device_id, COUNT(*) AS count
            FROM read_parquet(?, hive_partitioning = true)
            GROUP BY device_id
            ORDER BY count DESC
            """,
            [path],
        ).fetchall()
        return [{"device_id": r[0], "count": r[1]} for r in rows]
    except duckdb.Error as e:
        logger.warning("Analytics anomalies query failed: %s", e)
        return []


def get_config_changes_over_time() -> list[dict[str, Any]]:
    """Return time series: date (day) and count of configuration changes. Daily buckets."""
    if not _is_configured():
        return []
    path = _prescription_changes_path()
    if not path:
        return []
    try:
        conn = _get_conn()
        rows = conn.execute(
            """
            SELECT
                strftime(epoch_ms(changed_at)::TIMESTAMP, '%Y-%m-%d') AS date,
                COUNT(*) AS count
            FROM read_parquet(?, hive_partitioning = true)
            GROUP BY 1
            ORDER BY 1
            """,
            [path],
        ).fetchall()
        return [{"date": r[0], "count": r[1]} for r in rows]
    except duckdb.Error as e:
        logger.warning("Analytics config changes query failed: %s", e)
        return []


def get_new_devices_over_time() -> list[dict[str, Any]]:
    """Return time series: date (day) and count of new devices first seen. Daily buckets."""
    if not _is_configured():
        return []
    path = _device_first_seen_path()
    if not path:
        return []
    try:
        conn = _get_conn()
        rows = conn.execute(
            """
            SELECT
                strftime(epoch_ms(first_seen_at)::TIMESTAMP, '%Y-%m-%d') AS date,
                COUNT(*) AS count
            FROM read_parquet(?, hive_partitioning = true)
            GROUP BY 1
            ORDER BY 1
            """,
            [path],
        ).fetchall()
        return [{"date": r[0], "count": r[1]} for r in rows]
    except duckdb.Error as e:
        logger.warning("Analytics new devices query failed: %s", e)
        return []


def get_dashboard_data() -> dict[str, Any]:
    """Return all three metrics in one payload. Keys: anomalies_per_device, config_changes_over_time, new_devices_over_time."""
    return {
        "anomalies_per_device": get_anomalies_per_device(),
        "config_changes_over_time": get_config_changes_over_time(),
        "new_devices_over_time": get_new_devices_over_time(),
    }
