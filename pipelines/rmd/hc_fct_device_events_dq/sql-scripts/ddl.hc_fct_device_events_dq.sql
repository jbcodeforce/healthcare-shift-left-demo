CREATE TABLE IF NOT EXISTS hc_dim_cell_tower_zones (
  zone_id     STRING NOT NULL COMMENT 'Known bad GPS zone id',
  zone_name   STRING COMMENT 'Description',
  min_lat     DOUBLE NOT NULL COMMENT 'Bounding box min latitude',
  max_lat     DOUBLE NOT NULL COMMENT 'Bounding box max latitude',
  min_lng     DOUBLE NOT NULL COMMENT 'Bounding box min longitude',
  max_lng     DOUBLE NOT NULL COMMENT 'Bounding box max longitude',
  PRIMARY KEY (zone_id) NOT ENFORCED
) DISTRIBUTED BY HASH(zone_id) INTO 1 BUCKETS
WITH (
  'changelog.mode' = 'upsert',
  'key.format' = 'json-registry',
  'value.format' = 'json-registry',
  'kafka.retention.time' = '0',
  'kafka.producer.compression.type' = 'snappy',
  'scan.bounded.mode' = 'unbounded',
  'scan.startup.mode' = 'earliest-offset',
  'value.fields-include' = 'all'
);

CREATE TABLE IF NOT EXISTS hc_fct_device_events_dq (
  event_id      STRING NOT NULL COMMENT 'Source event id',
  device_id     STRING NOT NULL COMMENT 'Device identifier',
  patient_id    STRING NOT NULL COMMENT 'Patient identifier',
  event_type    STRING NOT NULL COMMENT 'Event type',
  event_ts      TIMESTAMP(3) COMMENT 'Event time',
  dq_reason     STRING NOT NULL COMMENT 'Quality failure reason',
  PRIMARY KEY (event_id, dq_reason) NOT ENFORCED
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
