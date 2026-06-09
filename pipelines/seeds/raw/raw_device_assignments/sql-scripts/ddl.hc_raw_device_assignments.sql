CREATE TABLE IF NOT EXISTS hc_raw_device_assignments (
  assignment_id STRING NOT NULL COMMENT 'Primary key',
  imei STRING,
  user_id STRING,
  assigned_at TIMESTAMP(3),
  active BOOLEAN,
  PRIMARY KEY (assignment_id) NOT ENFORCED
) DISTRIBUTED BY HASH(assignment_id) INTO 1 BUCKETS
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