CREATE TABLE IF NOT EXISTS hc_fct_dev_anomaly (
  device_id       STRING NOT NULL COMMENT 'Device identifier',
  ts              TIMESTAMP(0) NOT NULL COMMENT 'Event time (second precision)',
  pressure        DOUBLE NOT NULL COMMENT 'Pressure value',
  expected_pressure DOUBLE NOT NULL COMMENT 'Expected pressure value',
  lower_bound       DOUBLE NOT NULL COMMENT 'Lower bound',
  upper_bound       DOUBLE NOT NULL COMMENT 'Upper bound',
  is_surge        BOOLEAN NOT NULL COMMENT 'Whether the pressure is anomalous',
  -- put here column definitions
  PRIMARY KEY(device_id) NOT ENFORCED
) DISTRIBUTED BY HASH(device_id) INTO 1 BUCKETS
WITH (
  'changelog.mode' = 'append',
  'key.avro-registry.schema-context' = '.flink-dev',
  'value.avro-registry.schema-context' = '.flink-dev',
  'key.format' = 'avro-registry',
  'value.format' = 'avro-registry',
  'kafka.retention.time' = '0',
  'kafka.producer.compression.type' = 'snappy',
  'scan.bounded.mode' = 'unbounded',
  'scan.startup.mode' = 'earliest-offset',
  'value.fields-include' = 'all'
);