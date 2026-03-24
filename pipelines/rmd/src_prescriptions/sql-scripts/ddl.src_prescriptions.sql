CREATE TABLE IF NOT EXISTS hc_src_prescriptions (
  prescription_id       STRING NOT NULL COMMENT 'Primary key',
  patient_id            STRING COMMENT 'Patient identifier',
  device_id             STRING COMMENT 'Device identifier',
  medication_or_therapy STRING COMMENT 'e.g. CPAP Oxygen Flow',
  metric_name           STRING COMMENT 'Metric to control',
  target_value          DOUBLE COMMENT 'e.g. 2.5 (Liters per minute)',
  tolerance_range       DOUBLE COMMENT 'Acceptable +/- e.g. 0.5',
  start_date            TIMESTAMP(0)  COMMENT 'Start (epoch ms)',
  end_date              TIMESTAMP(0) COMMENT 'End (epoch ms)'
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