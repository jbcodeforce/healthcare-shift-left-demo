-- Debezium CDC raw layer: envelope with before/after as STRING (schema-less).
-- Downstream can parse JSON from before/after to evolve schema without DDL changes.
CREATE TABLE IF NOT EXISTS raw_patients (
  patient_id    STRING NOT NULL COMMENT 'Source primary key (from Debezium key)',
  before        STRING COMMENT 'Row state before change (JSON string); null for INSERT',
  after         STRING COMMENT 'Row state after change (JSON string); null for DELETE',
  op            STRING COMMENT 'Debezium op: c=create, u=update, d=delete, r=read/snapshot',
  source_ts_ms  BIGINT COMMENT 'Source event timestamp (ms)',
  PRIMARY KEY (patient_id) NOT ENFORCED
) DISTRIBUTED BY HASH(patient_id) INTO 1 BUCKETS
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
