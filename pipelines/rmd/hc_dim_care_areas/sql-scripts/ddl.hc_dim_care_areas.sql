CREATE TABLE IF NOT EXISTS hc_dim_care_areas (
  area_id     STRING NOT NULL COMMENT 'Geofence identifier',
  patient_id  STRING NOT NULL COMMENT 'Patient this fence protects',
  center_lat  DOUBLE NOT NULL COMMENT 'Circle center latitude',
  center_lng  DOUBLE NOT NULL COMMENT 'Circle center longitude',
  radius_m    DOUBLE NOT NULL COMMENT 'Radius in meters',
  PRIMARY KEY (area_id) NOT ENFORCED
) DISTRIBUTED BY HASH(area_id) INTO 1 BUCKETS
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
