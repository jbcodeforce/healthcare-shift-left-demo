"""PostgreSQL prescriptions table: one row per device, parameters as JSON string."""

import logging
import secrets
import string
from typing import Any

from backend.config import get_settings


def _short_id(length: int = 4) -> str:
    """Return a short alphanumeric id (e.g. a3F9) for unique prescription ids."""
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))

logger = logging.getLogger(__name__)

PRESCRIPTIONS_TABLE = """
DROP TABLE IF EXISTS prescriptions;
CREATE TABLE prescriptions (
    id SERIAL PRIMARY KEY,
    prescription_id VARCHAR(128) NOT NULL UNIQUE,
    patient_id VARCHAR(64) NOT NULL,
    device_id VARCHAR(64) NOT NULL,
    medication_or_therapy VARCHAR(256),
    start_date BIGINT,
    end_date BIGINT,
    parameters TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
"""


def _conn():
    s = get_settings()
    if not s.database_url:
        return None
    try:
        import psycopg
        return psycopg.connect(s.database_url)
    except Exception as e:
        logger.warning("Database connection failed: %s", e)
        return None


def init_prescriptions_table(conn) -> None:
    with conn.cursor() as cur:
        cur.execute(PRESCRIPTIONS_TABLE)
    conn.commit()


def ensure_prescriptions_table() -> None:
    """Create or replace prescriptions table. Call once at startup."""
    conn = _conn()
    if conn is None:
        return
    try:
        init_prescriptions_table(conn)
    finally:
        conn.close()


def seed_prescriptions(rows: list[dict[str, Any]]) -> None:
    """Insert prescription rows (one per device, parameters as JSON string). On conflict do nothing."""
    conn = _conn()
    if conn is None:
        return
    try:
        with conn.cursor() as cur:
            for r in rows:
                cur.execute(
                    """
                    INSERT INTO prescriptions (
                        prescription_id, patient_id, device_id, medication_or_therapy,
                        start_date, end_date, parameters
                    ) VALUES (%s, %s, %s, %s, %s, %s, %s)
                    ON CONFLICT (prescription_id) DO NOTHING
                    """,
                    (
                        r.get("prescriptionId"),
                        r.get("patientId"),
                        r.get("deviceId"),
                        r.get("medicationOrTherapy"),
                        r.get("startDate"),
                        r.get("endDate"),
                        r.get("parameters", "[]"),
                    ),
                )
        conn.commit()
    except Exception as e:
        logger.exception("Seed prescriptions failed: %s", e)
        conn.rollback()
    finally:
        conn.close()


def count_prescriptions() -> int:
    conn = _conn()
    if conn is None:
        return -1
    try:
        with conn.cursor() as cur:
            cur.execute("SELECT COUNT(*) FROM prescriptions")
            (n,) = cur.fetchone()
            return n
    except Exception as e:
        logger.warning("Count prescriptions failed: %s", e)
        return -1
    finally:
        conn.close()


def _row_to_prescription(r: tuple) -> dict[str, Any]:
    """Map DB row to API prescription dict (camelCase)."""
    return {
        "prescriptionId": r[0],
        "patientId": r[1],
        "deviceId": r[2],
        "medicationOrTherapy": r[3],
        "startDate": r[4],
        "endDate": r[5],
        "parameters": r[6] or "[]",
    }


def get_prescriptions_from_db() -> list[dict[str, Any]] | None:
    """Return list of prescriptions from PostgreSQL; parameters as raw string. None if DB not configured/fails."""
    conn = _conn()
    if conn is None:
        return None
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT prescription_id, patient_id, device_id, medication_or_therapy,
                       start_date, end_date, parameters
                FROM prescriptions
                ORDER BY device_id
                """
            )
            rows = cur.fetchall()
        return [_row_to_prescription(r) for r in rows]
    except Exception as e:
        logger.warning("Get prescriptions from DB failed: %s", e)
        return None
    finally:
        conn.close()


def get_prescription_by_id(prescription_id: str) -> dict[str, Any] | None:
    """Return one prescription by prescription_id, or None if not found / DB unavailable."""
    conn = _conn()
    if conn is None:
        return None
    try:
        with conn.cursor() as cur:
            cur.execute(
                """
                SELECT prescription_id, patient_id, device_id, medication_or_therapy,
                       start_date, end_date, parameters
                FROM prescriptions
                WHERE prescription_id = %s
                """,
                (prescription_id,),
            )
            row = cur.fetchone()
        return _row_to_prescription(row) if row else None
    except Exception as e:
        logger.warning("Get prescription by id failed: %s", e)
        return None
    finally:
        conn.close()


def create_prescription(row: dict[str, Any]) -> dict[str, Any] | None:
    """Insert one prescription. Returns the created prescription dict or None on failure.
    Prescription ID is always generated with a 4-char suffix to avoid duplicates (e.g. RX-DEV-P002-a3F9).
    """
    conn = _conn()
    if conn is None:
        return None
    try:
        device_id = row.get("deviceId", "")
        prescription_id = f"RX-{device_id}-{_short_id(4)}"
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO prescriptions (
                    prescription_id, patient_id, device_id, medication_or_therapy,
                    start_date, end_date, parameters
                ) VALUES (%s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    prescription_id,
                    row.get("patientId"),
                    row.get("deviceId"),
                    row.get("medicationOrTherapy") or "",
                    row.get("startDate"),
                    row.get("endDate"),
                    row.get("parameters", "[]"),
                ),
            )
        conn.commit()
        return get_prescription_by_id(prescription_id)
    except Exception as e:
        logger.exception("Create prescription failed: %s", e)
        conn.rollback()
        return None
    finally:
        conn.close()


def update_prescription(prescription_id: str, row: dict[str, Any]) -> dict[str, Any] | None:
    """Update prescription by prescription_id. Only provided fields are updated. Returns updated dict or None."""
    conn = _conn()
    if conn is None:
        return None
    try:
        existing = get_prescription_by_id(prescription_id)
        if not existing:
            return None
        patient_id = row.get("patientId") if "patientId" in row else existing["patientId"]
        device_id = row.get("deviceId") if "deviceId" in row else existing["deviceId"]
        medication = row.get("medicationOrTherapy") if "medicationOrTherapy" in row else existing["medicationOrTherapy"]
        start_date = row.get("startDate") if "startDate" in row else existing["startDate"]
        end_date = row.get("endDate") if "endDate" in row else existing["endDate"]
        parameters = row.get("parameters") if "parameters" in row else existing["parameters"]
        with conn.cursor() as cur:
            cur.execute(
                """
                UPDATE prescriptions
                SET patient_id = %s, device_id = %s, medication_or_therapy = %s,
                    start_date = %s, end_date = %s, parameters = %s
                WHERE prescription_id = %s
                """,
                (patient_id, device_id, medication, start_date, end_date, parameters, prescription_id),
            )
        conn.commit()
        return get_prescription_by_id(prescription_id)
    except Exception as e:
        logger.exception("Update prescription failed: %s", e)
        conn.rollback()
        return None
    finally:
        conn.close()


def delete_prescription(prescription_id: str) -> bool:
    """Delete prescription by prescription_id. Returns True if deleted, False if not found or DB unavailable."""
    conn = _conn()
    if conn is None:
        return False
    try:
        with conn.cursor() as cur:
            cur.execute("DELETE FROM prescriptions WHERE prescription_id = %s", (prescription_id,))
            deleted = cur.rowcount
        conn.commit()
        return deleted > 0
    except Exception as e:
        logger.exception("Delete prescription failed: %s", e)
        conn.rollback()
        return False
    finally:
        conn.close()
