CREATE TABLE IF NOT EXISTS hc_raw_device_events_ut (
  event_id STRING,
  device_id STRING,
  patient_id STRING,
  event_type STRING,
  lng DOUBLE,
  lat DOUBLE,
  battery_level INT,
  plugged BOOLEAN,
  hw_model STRING,
  sw_version STRING,
  event_ts TIMESTAMP(3),
  PRIMARY KEY (event_id) NOT ENFORCED
);
