CREATE TABLE IF NOT EXISTS hc_src_patients_ut (
  patient_id STRING,
  name STRING,
  gender STRING,
  birth_date STRING,
  zip_code STRING,
  timezone STRING,
  source_ts_ms BIGINT,
  op STRING,
  PRIMARY KEY (patient_id) NOT ENFORCED
);
