-- Button press routing: registry (state), verification sink, emergency alert sink.
CREATE TABLE IF NOT EXISTS hc_fct_assignment_verification_registry (
  assignment_id   STRING NOT NULL COMMENT 'Assignment that completed first-press verification',
  device_id       STRING NOT NULL COMMENT 'Device identifier',
  patient_id      STRING NOT NULL COMMENT 'Patient identifier',
  first_press_ts  TIMESTAMP(3) COMMENT 'Timestamp of first verified press',
  first_event_id  STRING COMMENT 'Source event id',
  PRIMARY KEY (assignment_id) NOT ENFORCED
) DISTRIBUTED BY HASH(assignment_id) INTO 1 BUCKETS
WITH (
  'changelog.mode' = 'upsert',
  'key.format' = 'json-registry',
  'value.format' = 'avro-registry',
  'kafka.retention.time' = '0',
  'kafka.producer.compression.type' = 'snappy',
  'scan.bounded.mode' = 'unbounded',
  'scan.startup.mode' = 'earliest-offset',
  'value.fields-include' = 'all'
);

CREATE TABLE IF NOT EXISTS hc_fct_device_verification (
  event_id        STRING NOT NULL COMMENT 'Source event id',
  device_id       STRING NOT NULL COMMENT 'Device identifier',
  patient_id      STRING NOT NULL COMMENT 'Patient identifier',
  assignment_id   STRING NOT NULL COMMENT 'Active assignment',
  event_ts        TIMESTAMP(3) NOT NULL COMMENT 'Button press time',
  route_reason    STRING NOT NULL COMMENT 'Routing label',
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

CREATE TABLE IF NOT EXISTS hc_fct_device_alert (
  event_id        STRING NOT NULL COMMENT 'Source event id',
  device_id       STRING NOT NULL COMMENT 'Device identifier',
  patient_id      STRING NOT NULL COMMENT 'Patient identifier',
  assignment_id   STRING NOT NULL COMMENT 'Active assignment',
  event_ts        TIMESTAMP(3) NOT NULL COMMENT 'Button press time',
  route_reason    STRING NOT NULL COMMENT 'Routing label',
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
