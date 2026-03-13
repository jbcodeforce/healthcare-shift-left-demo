CREATE TABLE IF NOT EXISTS hc_src_devices (
  device_id          STRING NOT NULL COMMENT 'Primary key',
  patient_id         STRING COMMENT 'Patient identifier',
  model_type         STRING COMMENT 'Model type',
  manufacturer       STRING COMMENT 'Manufacturer',
  serial_number      STRING COMMENT 'Serial number',
  software_version   STRING COMMENT 'Software version',
  pressure_setting   DOUBLE COMMENT 'Pressure setting',
  flow_rate_setting  DOUBLE COMMENT 'Flow rate setting',
  flow_level         INT COMMENT 'Flow level',
  PRIMARY KEY (device_id) NOT ENFORCED
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