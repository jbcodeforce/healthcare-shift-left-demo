#!/usr/bin/env python3
"""
Generate sample Parquet tables for S3 analytics validation.

Creates three tables matching the dashboard expectations:
  - anomalies: device_id, ts, metric_name, severity
  - prescription_changes: device_id, changed_at, operation, prescription_id
  - device_first_seen: device_id, first_seen_at

Run from repo root:
  pip install duckdb   # or: uv add duckdb (in backend)
  python analytics/sample-data/generate_sample_data.py

Output is written to analytics/sample-data/parquet/ (and optionally
analytics/sample-data/parquet-partitioned/). Upload that folder to S3
and point the backend at s3://your-bucket/parquet/ (or the partitioned prefix).
"""

from pathlib import Path
import duckdb

OUTPUT_DIR = Path(__file__).resolve().parent / "parquet"
PARTITIONED_DIR = Path(__file__).resolve().parent / "parquet-partitioned"


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    PARTITIONED_DIR.mkdir(parents=True, exist_ok=True)

    con = duckdb.connect(":memory:")

    # --- anomalies: one row per anomaly event ---
    con.execute("""
        CREATE TABLE anomalies AS
        SELECT
            device_id,
            ts,
            metric_name,
            severity
        FROM (VALUES
            ('DEV-P001', 1710000000000, 'Pressure', 'high'),
            ('DEV-P001', 1710003600000, 'FlowRate', 'low'),
            ('DEV-P001', 1710007200000, 'Pressure', 'high'),
            ('DEV-P002', 1710001000000, 'MotorSpeed', 'high'),
            ('DEV-P002', 1710004600000, 'Pressure', 'low'),
            ('DEV-P003', 1710002000000, 'FlowRate', 'high'),
            ('DEV-P003', 1710005000000, 'FlowRate', 'high'),
            ('DEV-P004', 1710003000000, 'Pressure', 'high'),
            ('DEV-P005', 1710004000000, 'MotorSpeed', 'low')
        ) AS t(device_id, ts, metric_name, severity)
    """)
    con.execute(f"COPY anomalies TO '{OUTPUT_DIR / "anomalies.parquet"}' (FORMAT parquet)")
    # Partitioned by date for larger datasets
    con.execute("ALTER TABLE anomalies ADD COLUMN date DATE")
    con.execute("UPDATE anomalies SET date = epoch_ms(ts)::DATE")
    con.execute(f"COPY anomalies TO '{PARTITIONED_DIR / "anomalies"}' (FORMAT parquet, PARTITION_BY (date))")
    print(f"Wrote anomalies -> {OUTPUT_DIR / 'anomalies.parquet'} and partitioned -> {PARTITIONED_DIR / 'anomalies'}")

    # --- prescription_changes: config change history per device ---
    con.execute("""
        CREATE TABLE prescription_changes AS
        SELECT
            device_id,
            changed_at,
            operation,
            prescription_id
        FROM (VALUES
            ('DEV-P001', 1709000000000, 'INSERT', 'RX-DEV-P001-a1b2'),
            ('DEV-P001', 1710000000000, 'UPDATE', 'RX-DEV-P001-a1b2'),
            ('DEV-P001', 1710100000000, 'UPDATE', 'RX-DEV-P001-a1b2'),
            ('DEV-P002', 1709100000000, 'INSERT', 'RX-DEV-P002-c3d4'),
            ('DEV-P002', 1710200000000, 'UPDATE', 'RX-DEV-P002-c3d4'),
            ('DEV-P003', 1709200000000, 'INSERT', 'RX-DEV-P003-e5f6'),
            ('DEV-P004', 1709300000000, 'INSERT', 'RX-DEV-P004-g7h8'),
            ('DEV-P004', 1710300000000, 'UPDATE', 'RX-DEV-P004-g7h8'),
            ('DEV-P005', 1709400000000, 'INSERT', 'RX-DEV-P005-i9j0')
        ) AS t(device_id, changed_at, operation, prescription_id)
    """)
    con.execute(f"COPY prescription_changes TO '{OUTPUT_DIR / "prescription_changes.parquet"}' (FORMAT parquet)")
    con.execute("ALTER TABLE prescription_changes ADD COLUMN date DATE")
    con.execute("UPDATE prescription_changes SET date = epoch_ms(changed_at)::DATE")
    con.execute(f"COPY prescription_changes TO '{PARTITIONED_DIR / "prescription_changes"}' (FORMAT parquet, PARTITION_BY (date))")
    print(f"Wrote prescription_changes -> {OUTPUT_DIR / 'prescription_changes.parquet'} and partitioned")

    # --- device_first_seen: when each device was first seen ---
    con.execute("""
        CREATE TABLE device_first_seen AS
        SELECT
            device_id,
            first_seen_at
        FROM (VALUES
            ('DEV-P001', 1709000000000),
            ('DEV-P002', 1709100000000),
            ('DEV-P003', 1709200000000),
            ('DEV-P004', 1709300000000),
            ('DEV-P005', 1709400000000),
            ('DEV-P006', 1710400000000),
            ('DEV-P007', 1710500000000)
        ) AS t(device_id, first_seen_at)
    """)
    con.execute(f"COPY device_first_seen TO '{OUTPUT_DIR / "device_first_seen.parquet"}' (FORMAT parquet)")
    con.execute("ALTER TABLE device_first_seen ADD COLUMN date DATE")
    con.execute("UPDATE device_first_seen SET date = epoch_ms(first_seen_at)::DATE")
    con.execute(f"COPY device_first_seen TO '{PARTITIONED_DIR / "device_first_seen"}' (FORMAT parquet, PARTITION_BY (date))")
    print(f"Wrote device_first_seen -> {OUTPUT_DIR / 'device_first_seen.parquet'} and partitioned")

    con.close()
    print("\nDone. Upload the 'parquet' or 'parquet-partitioned' folder to S3 and set ANALYTICS_S3_* in the backend.")


if __name__ == "__main__":
    main()
