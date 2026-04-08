CREATE TABLE IF NOT EXISTS hc_raw_devices (
  device_id          STRING NOT NULL COMMENT 'Primary key',
  model_type         STRING COMMENT 'Model type',
  manufacturer       STRING COMMENT 'Manufacturer',
  serial_number      STRING COMMENT 'Serial number',
  software_version   STRING COMMENT 'Software version',
  created_at         BIGINT COMMENT 'Created at (epoch ms)',
  updated_at         BIGINT COMMENT 'Updated at (epoch ms)',
  patient_id         STRING COMMENT 'Patient identifier',
  pressure_setting   DOUBLE COMMENT 'Pressure setting',
  flow_rate_setting  DOUBLE COMMENT 'Flow rate setting',
  flow_level_setting INT COMMENT 'Flow Levelsetting',
  PRIMARY KEY (device_id) NOT ENFORCED
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