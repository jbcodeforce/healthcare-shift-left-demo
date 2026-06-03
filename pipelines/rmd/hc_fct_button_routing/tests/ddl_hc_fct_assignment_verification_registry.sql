CREATE TABLE IF NOT EXISTS hc_fct_assignment_verification_registry_ut (
  assignment_id STRING,
  device_id STRING,
  patient_id STRING,
  first_press_ts TIMESTAMP(3),
  first_event_id STRING,
  PRIMARY KEY (assignment_id) NOT ENFORCED
);
