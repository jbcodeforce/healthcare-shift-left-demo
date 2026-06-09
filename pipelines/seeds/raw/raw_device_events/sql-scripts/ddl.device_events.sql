-- Raw device lifecycle events (button press, power status, GPS) for BBH-style use cases.
CREATE TABLE IF NOT EXISTS hc_raw_device_events (
  event_id       STRING NOT NULL COMMENT 'Unique event identifier',
  device_id      STRING NOT NULL COMMENT 'Device identifier (demo: DEV-P001)',
  patient_id     STRING NOT NULL COMMENT 'Patient identifier (demo: P001)',
  event_type     STRING NOT NULL COMMENT 'BUTTON_PRESSED | POWER_STATUS | GPS',
  lng            DOUBLE COMMENT 'Longitude (GPS events)',
  lat            DOUBLE COMMENT 'Latitude (GPS events)',
  battery_level  INT COMMENT 'Battery percentage (power events)',
  plugged        BOOLEAN COMMENT 'On charger (power events)',
  hw_model       STRING COMMENT 'Hardware model',
  sw_version     STRING COMMENT 'Software/firmware version',
  event_ts       TIMESTAMP(3) NOT NULL COMMENT 'Event time',
  PRIMARY KEY (event_id) NOT ENFORCED,
  WATERMARK FOR event_ts AS event_ts - INTERVAL '5' SECOND
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
