-- Fact table: 1-hour tumbling window aggregates per device/patient/metric.
-- Source: hc_device_metrics. Uses processing-time windowing (PROCTIME).
CREATE TABLE IF NOT EXISTS hc_fct_telemetry_1h (
  window_start   TIMESTAMP(3) NOT NULL COMMENT 'Window start (inclusive)',
  window_end     TIMESTAMP(3) NOT NULL COMMENT 'Window end (exclusive)',
  device_id      STRING NOT NULL COMMENT 'Device identifier',
  patient_id     STRING NOT NULL COMMENT 'Patient identifier',
  metric_name    STRING NOT NULL COMMENT 'e.g. Pressure, FlowRate, MotorSpeed',
  avg_value      DOUBLE NOT NULL COMMENT 'Average metric value in window',
  min_value      DOUBLE NOT NULL COMMENT 'Min metric value in window',
  max_value      DOUBLE NOT NULL COMMENT 'Max metric value in window',
  count_reading  BIGINT NOT NULL COMMENT 'Number of readings in window',
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
