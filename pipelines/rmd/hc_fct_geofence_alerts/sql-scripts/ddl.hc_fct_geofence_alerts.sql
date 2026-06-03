CREATE TABLE IF NOT EXISTS hc_fct_geofence_alerts (
  area_id     STRING NOT NULL COMMENT 'Geofence breached',
  patient_id  STRING NOT NULL COMMENT 'Patient at risk',
  device_id   STRING NOT NULL COMMENT 'Reporting device',
  lat         DOUBLE NOT NULL COMMENT 'Observed latitude',
  lng         DOUBLE NOT NULL COMMENT 'Observed longitude',
  event_ts    TIMESTAMP(3) NOT NULL COMMENT 'GPS event time',
  event_id    STRING NOT NULL COMMENT 'Source event id',
  PRIMARY KEY (event_id, area_id) NOT ENFORCED
) DISTRIBUTED BY HASH(patient_id) INTO 1 BUCKETS
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
