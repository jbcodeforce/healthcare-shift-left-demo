-- Fact table: one row per parameter drift event (telemetry outside target ± tolerance).
-- Source: join of hc_device_metrics (observed) and hc_src_prescriptions (desired) with patient information.
CREATE TABLE IF NOT EXISTS hc_fct_drift_evts (
  device_id         STRING NOT NULL COMMENT 'Device identifier',
  patient_id        STRING NOT NULL COMMENT 'Patient identifier',
  name              STRING  COMMENT 'Patient name',
  gender            STRING  COMMENT 'Patient gender',
  birth_date        STRING COMMENT 'Patient birth date',
  ts                BIGINT NOT NULL COMMENT 'Event time (epoch ms)',
  prescription_id   STRING COMMENT 'Prescription that defined the target',
  metric_name       STRING NOT NULL COMMENT 'e.g. Pressure, FlowRate, FlowLevel',
  prescribed_value  DOUBLE NOT NULL COMMENT 'Target from prescription',
  actual_value      DOUBLE NOT NULL COMMENT 'Observed telemetry value',
  tolerance_range   DOUBLE NOT NULL COMMENT 'Acceptable +/- from prescription',
  drift_direction   STRING NOT NULL COMMENT 'Above range | Below range',
  deviation         DOUBLE NOT NULL COMMENT 'actual_value - prescribed_value (signed)',
  message           STRING COMMENT 'Human-readable drift description',
  PRIMARY KEY (patient_id, device_id, metric_name) NOT ENFORCED
) DISTRIBUTED BY HASH(patient_id, device_id, metric_name) INTO 1 BUCKETS
WITH (
  'changelog.mode' = 'upsert',
  'key.format' = 'avro-registry',
  'value.format' = 'avro-registry',
  'kafka.retention.time' = '0',
  'kafka.producer.compression.type' = 'snappy',
  'scan.bounded.mode' = 'unbounded',
  'scan.startup.mode' = 'earliest-offset',
  'value.fields-include' = 'all'
);
