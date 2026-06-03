CREATE TABLE IF NOT EXISTS hc_src_device_update_allowlist (
  device_id           STRING NOT NULL COMMENT 'Device eligible for OTA',
  target_sw_version   STRING NOT NULL COMMENT 'Target firmware version',
  update_enabled      BOOLEAN NOT NULL COMMENT 'Ops toggle',
  PRIMARY KEY (device_id) NOT ENFORCED
) DISTRIBUTED BY HASH(device_id) INTO 1 BUCKETS
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
