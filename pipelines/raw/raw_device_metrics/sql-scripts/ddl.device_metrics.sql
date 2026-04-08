CREATE TABLE IF NOT EXISTS hc_raw_device_metrics (
  device_id       STRING NOT NULL COMMENT 'Device identifier',
  patient_id      STRING NOT NULL COMMENT 'Patient identifier',
  ts              TIMESTAMP(0) NOT NULL COMMENT 'Event time (second precision)',
  metric_name     STRING NOT NULL COMMENT 'e.g. Pressure, FlowRate, FlowLevel',
  metric_value    DOUBLE NOT NULL COMMENT 'Observed value',
  software_version STRING COMMENT 'Firmware/software version (debugging)',
  PRIMARY KEY (device_id, metric_name) NOT ENFORCED,
  WATERMARK FOR ts AS ts - INTERVAL '5' SECOND
) DISTRIBUTED BY HASH(device_id) INTO 1 BUCKETS
WITH (
  'changelog.mode' = 'append',
  'key.format' = 'avro-registry',
  'value.format' = 'avro-registry',
  'kafka.retention.time' = '0',
  'kafka.producer.compression.type' = 'snappy',
  'scan.bounded.mode' = 'unbounded',
  'scan.startup.mode' = 'earliest-offset',
  'value.fields-include' = 'all'
);