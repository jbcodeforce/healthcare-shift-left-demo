CREATE TABLE IF NOT EXISTS hc_src_device_assignments_ut (
  assignment_id STRING,
  device_id STRING,
  patient_id STRING,
  assigned_at BIGINT,
  active BOOLEAN,
  PRIMARY KEY (assignment_id) NOT ENFORCED
);
