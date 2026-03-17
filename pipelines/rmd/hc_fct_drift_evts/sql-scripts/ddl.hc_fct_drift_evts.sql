-- Fact table: one row per prescription drift event (telemetry outside target ± tolerance).
-- Source: join of hc_device_metrics (observed) and hc_src_prescriptions (desired).
CREATE TABLE IF NOT EXISTS hc_fct_drift_evts (
  device_id         STRING NOT NULL COMMENT 'Device identifier',
  patient_id        STRING NOT NULL COMMENT 'Patient identifier',
  ts                BIGINT NOT NULL COMMENT 'Event time (epoch ms)',
  prescription_id   STRING COMMENT 'Prescription that defined the target',
  metric_name       STRING NOT NULL COMMENT 'e.g. Pressure, FlowRate, MotorSpeed',
  prescribed_value  DOUBLE NOT NULL COMMENT 'Target from prescription',
  actual_value      DOUBLE NOT NULL COMMENT 'Observed telemetry value',
  tolerance_range   DOUBLE NOT NULL COMMENT 'Acceptable +/- from prescription',
  drift_direction   STRING NOT NULL COMMENT 'Above range | Below range',
  deviation         DOUBLE NOT NULL COMMENT 'actual_value - prescribed_value (signed)',
  message           STRING COMMENT 'Human-readable drift description',
  PRIMARY KEY (device_id, ts, metric_name) NOT ENFORCED
) DISTRIBUTED BY HASH(device_id) INTO 1 BUCKETS
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
