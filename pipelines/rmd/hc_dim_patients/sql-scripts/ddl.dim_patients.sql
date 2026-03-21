CREATE TABLE IF NOT EXISTS hc_dim_patients (
  patient_id   STRING NOT NULL COMMENT 'Primary key',
  name         STRING COMMENT 'Patient name',
  gender       STRING COMMENT 'Gender',
  birth_date   STRING COMMENT 'Birth date',
  device_id    STRING COMMENT 'Device identifier',
  model_type   STRING COMMENT 'Model type',
  serial_number STRING COMMENT 'Serial number',
  pressure_setting DOUBLE COMMENT 'Pressure setting',
  flow_rate_setting DOUBLE COMMENT 'Flow rate setting',
  flow_level_setting INT COMMENT 'Flow level',
  -- put here column definitions
  PRIMARY KEY(patient_id) NOT ENFORCED
) DISTRIBUTED BY HASH(patient_id) INTO 1 BUCKETS
WITH (
  'changelog.mode' = 'upsert',
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