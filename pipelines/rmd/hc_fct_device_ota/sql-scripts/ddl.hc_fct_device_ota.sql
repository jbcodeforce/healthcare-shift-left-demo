CREATE TABLE IF NOT EXISTS hc_fct_device_power_latest (
  device_id         STRING NOT NULL COMMENT 'Device identifier',
  battery_level     INT COMMENT 'Latest battery percentage',
  plugged           BOOLEAN COMMENT 'Latest charger state',
  power_status_ts   TIMESTAMP(3) COMMENT 'Latest power event time',
  power_event_id    STRING COMMENT 'Latest power event id',
  PRIMARY KEY (device_id) NOT ENFORCED
) DISTRIBUTED BY HASH(device_id) INTO 1 BUCKETS
WITH (
  'changelog.mode' = 'upsert',
  'key.format' = 'json-registry',
  'value.format' = 'avro-registry',
  'kafka.retention.time' = '0',
  'kafka.producer.compression.type' = 'snappy',
  'scan.bounded.mode' = 'unbounded',
  'scan.startup.mode' = 'earliest-offset',
  'value.fields-include' = 'all'
);

CREATE TABLE IF NOT EXISTS hc_fct_device_update_registry (
  device_id           STRING NOT NULL COMMENT 'Device updated',
  target_sw_version   STRING NOT NULL COMMENT 'Firmware target applied',
  updated_at          TIMESTAMP(3) COMMENT 'Update command time',
  update_event_id     STRING COMMENT 'Triggering power event id',
  PRIMARY KEY (device_id, target_sw_version) NOT ENFORCED
) DISTRIBUTED BY HASH(device_id) INTO 1 BUCKETS
WITH (
  'changelog.mode' = 'upsert',
  'key.format' = 'json-registry',
  'value.format' = 'avro-registry',
  'kafka.retention.time' = '0',
  'kafka.producer.compression.type' = 'snappy',
  'scan.bounded.mode' = 'unbounded',
  'scan.startup.mode' = 'earliest-offset',
  'value.fields-include' = 'all'
);

CREATE TABLE IF NOT EXISTS hc_fct_device_update_commands (
  command_id          STRING NOT NULL COMMENT 'Command id',
  device_id           STRING NOT NULL COMMENT 'Device to update',
  patient_id          STRING NOT NULL COMMENT 'Assigned patient',
  target_sw_version   STRING NOT NULL COMMENT 'Target firmware',
  battery_level       INT COMMENT 'Battery at eligibility',
  eligible_at         TIMESTAMP(3) COMMENT 'Eligibility timestamp',
  route_reason        STRING NOT NULL COMMENT 'State machine label',
  PRIMARY KEY (command_id) NOT ENFORCED
) DISTRIBUTED BY HASH(device_id) INTO 1 BUCKETS
WITH (
  'changelog.mode' = 'append',
  'key.format' = 'json-registry',
  'value.format' = 'avro-registry',
  'kafka.retention.time' = '0',
  'kafka.producer.compression.type' = 'snappy',
  'scan.bounded.mode' = 'unbounded',
  'scan.startup.mode' = 'earliest-offset',
  'value.fields-include' = 'all'
);
