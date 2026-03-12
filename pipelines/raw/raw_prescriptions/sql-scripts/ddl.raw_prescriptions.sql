-- Debezium CDC raw layer: envelope with before/after as ROW (schema from src_prescriptions).
-- before/after have the same structure as src_prescriptions; null for INSERT (before) or DELETE (after).
CREATE TABLE IF NOT EXISTS raw_prescriptions (
  prescription_id STRING NOT NULL COMMENT 'Source primary key (from Debezium key)',
  before ROW(
    prescription_id       STRING,
    patient_id            STRING,
    device_id             STRING,
    medication_or_therapy STRING,
    metric_name           STRING,
    target_value          DOUBLE,
    tolerance_range       DOUBLE,
    start_date            BIGINT,
    end_date              BIGINT
  ) COMMENT 'Row state before change; null for INSERT',
  after ROW(
    prescription_id       STRING,
    patient_id            STRING,
    device_id             STRING,
    medication_or_therapy STRING,
    metric_name           STRING,
    target_value          DOUBLE,
    tolerance_range       DOUBLE,
    start_date            BIGINT,
    end_date              BIGINT
  ) COMMENT 'Row state after change; null for DELETE',
  op           STRING COMMENT 'Debezium op: c=create, u=update, d=delete, r=read/snapshot',
  source_ts_ms BIGINT COMMENT 'Source event timestamp (ms)',
  PRIMARY KEY (prescription_id) NOT ENFORCED
) DISTRIBUTED BY HASH(prescription_id) INTO 1 BUCKETS
WITH (
  'changelog.mode' = 'append',
  'key.avro-registry.schema-context' = '.flink-dev',
  'value.avro-registry.schema-context' = '.flink-dev',
  'key.format' = 'avro-registry',
  'value.format' = 'avro-registry',
  'kafka.retention.time' = '0',
  'kafka.producer.compression.type' = 'snappy',
  'scan.bounded.mode' = 'unbounded',
  'scan.startup.mode' = 'earliest-offset',
  'value.fields-include' = 'all'
);
