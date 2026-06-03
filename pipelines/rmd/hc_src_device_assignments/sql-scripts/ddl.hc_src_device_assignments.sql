CREATE TABLE IF NOT EXISTS hc_src_device_assignments (
  assignment_id STRING NOT NULL COMMENT 'Primary key',
  device_id     STRING NOT NULL COMMENT 'Device identifier',
  patient_id    STRING NOT NULL COMMENT 'Patient identifier',
  assigned_at   BIGINT COMMENT 'Assignment start time (epoch ms)',
  active        BOOLEAN NOT NULL COMMENT 'Current assignment flag',
  PRIMARY KEY (assignment_id) NOT ENFORCED
) DISTRIBUTED BY HASH(assignment_id) INTO 1 BUCKETS
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
