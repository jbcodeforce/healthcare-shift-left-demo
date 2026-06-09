CREATE TABLE IF NOT EXISTS hc_dim_patients (
  patient_id   STRING NOT NULL COMMENT 'Primary key',
  name         STRING COMMENT 'Patient name',
  gender       STRING COMMENT 'Gender',
  birth_date   STRING COMMENT 'Birth date',
  model_type   STRING COMMENT 'Model type',
  serial_number STRING COMMENT 'Serial number',
  device_id    STRING NOT NULL COMMENT 'Device identifier',
  device_pressure DOUBLE COMMENT 'Pressure setting',
  device_flow_rate DOUBLE COMMENT 'Flow rate setting',
  device_flow_level INT COMMENT 'Flow level',
  prescription_pressure DOUBLE COMMENT 'Pressure setting',
  prescription_flow_rate DOUBLE COMMENT 'Flow rate setting',
  prescription_flow_level INT COMMENT 'Flow level',
  -- put here column definitions
  PRIMARY KEY(patient_id, device_id) NOT ENFORCED
) DISTRIBUTED BY HASH(patient_id, device_id) INTO 1 BUCKETS
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