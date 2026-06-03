CREATE TABLE IF NOT EXISTS hc_src_patients (
  patient_id   STRING NOT NULL COMMENT 'Primary key',
  name         STRING COMMENT 'Patient name',
  gender       STRING COMMENT 'Gender',
  birth_date   STRING COMMENT 'Birth date',
  zip_code     STRING COMMENT 'Zip code (for geo-aggregations)',
  timezone     STRING COMMENT 'IANA timezone for daylight-hour OTA gate',
  source_ts_ms BIGINT COMMENT 'Source timestamp in milliseconds',
  op           STRING COMMENT 'Debezium op: c=create, u=update, d=delete, r=read/snapshot',
  PRIMARY KEY (patient_id) NOT ENFORCED
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