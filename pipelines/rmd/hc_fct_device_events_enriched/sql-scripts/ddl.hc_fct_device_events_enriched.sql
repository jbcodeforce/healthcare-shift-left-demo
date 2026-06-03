CREATE TABLE IF NOT EXISTS hc_fct_device_events_enriched (
  event_id        STRING NOT NULL COMMENT 'Source event id',
  device_id       STRING NOT NULL COMMENT 'Device identifier',
  patient_id      STRING NOT NULL COMMENT 'Patient identifier',
  event_type      STRING NOT NULL COMMENT 'Event type',
  event_ts        TIMESTAMP(3) NOT NULL COMMENT 'Event time',
  patient_name    STRING COMMENT 'Enriched patient name',
  zip_code        STRING COMMENT 'Enriched zip code',
  timezone        STRING COMMENT 'Enriched timezone',
  model_type      STRING COMMENT 'Enriched device model',
  serial_number   STRING COMMENT 'Enriched serial number',
  software_version STRING COMMENT 'Enriched software version',
  PRIMARY KEY (event_id) NOT ENFORCED
) DISTRIBUTED BY HASH(event_id) INTO 1 BUCKETS
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
