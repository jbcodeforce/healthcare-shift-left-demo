CREATE TABLE IF NOT EXISTS hc_src_device_update_allowlist_ut (
  device_id STRING,
  target_sw_version STRING,
  update_enabled BOOLEAN,
  PRIMARY KEY (device_id) NOT ENFORCED
);
