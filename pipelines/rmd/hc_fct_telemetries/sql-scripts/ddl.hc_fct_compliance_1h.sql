-- Fact table: 1-hour compliance per device/patient/metric (in-range vs total, compliance_pct).
-- Source: join hc_device_metrics with hc_src_prescriptions; readings in prescription range vs total per window.
CREATE TABLE IF NOT EXISTS hc_fct_compliance_1h (
  window_start       TIMESTAMP(3) NOT NULL COMMENT 'Window start (inclusive)',
  window_end         TIMESTAMP(3) NOT NULL COMMENT 'Window end (exclusive)',
  device_id          STRING NOT NULL COMMENT 'Device identifier',
  patient_id         STRING NOT NULL COMMENT 'Patient identifier',
  metric_name        STRING NOT NULL COMMENT 'e.g. Pressure, FlowRate, MotorSpeed',
  readings_in_range  BIGINT NOT NULL COMMENT 'Readings within target ± tolerance',
  readings_total     BIGINT NOT NULL COMMENT 'Total readings in window',
  compliance_pct     DOUBLE COMMENT 'readings_in_range / readings_total * 100',
  PRIMARY KEY (device_id, patient_id, metric_name, window_start) NOT ENFORCED
) DISTRIBUTED BY HASH(device_id) INTO 1 BUCKETS
WITH (
  'changelog.mode' = 'upsert',
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
