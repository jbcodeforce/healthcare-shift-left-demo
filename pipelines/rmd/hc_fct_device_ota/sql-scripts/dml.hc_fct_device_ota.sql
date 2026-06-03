-- OTA state machine: maintain power status, emit update commands during daylight when charger-ready.
EXECUTE STATEMENT SET
BEGIN
  INSERT INTO hc_fct_device_power_latest
  SELECT
    device_id,
    battery_level,
    plugged,
    event_ts AS power_status_ts,
    event_id AS power_event_id
  FROM hc_raw_device_events
  WHERE event_type = 'POWER_STATUS';

  INSERT INTO hc_fct_device_update_commands
  SELECT
    p.power_event_id AS command_id,
    p.device_id,
    da.patient_id,
    a.target_sw_version,
    p.battery_level,
    p.power_status_ts AS eligible_at,
    'DAYLIGHT_CHARGER_READY' AS route_reason
  FROM hc_fct_device_power_latest AS p
  INNER JOIN hc_src_device_update_allowlist AS a
    ON p.device_id = a.device_id
   AND a.update_enabled = TRUE
  INNER JOIN hc_src_device_assignments AS da
    ON p.device_id = da.device_id
   AND da.active = TRUE
  INNER JOIN hc_src_patients AS u
    ON da.patient_id = u.patient_id
  LEFT JOIN hc_fct_device_update_registry AS r
    ON p.device_id = r.device_id
   AND r.target_sw_version = a.target_sw_version
  WHERE p.plugged = TRUE
    AND p.battery_level >= 50
    AND r.device_id IS NULL
    AND HOUR(CONVERT_TZ(p.power_status_ts, 'UTC', u.timezone)) BETWEEN 7 AND 18;

  INSERT INTO hc_fct_device_update_registry
  SELECT
    p.device_id,
    a.target_sw_version,
    p.power_status_ts AS updated_at,
    p.power_event_id AS update_event_id
  FROM hc_fct_device_power_latest AS p
  INNER JOIN hc_src_device_update_allowlist AS a
    ON p.device_id = a.device_id
   AND a.update_enabled = TRUE
  INNER JOIN hc_src_device_assignments AS da
    ON p.device_id = da.device_id
   AND da.active = TRUE
  INNER JOIN hc_src_patients AS u
    ON da.patient_id = u.patient_id
  LEFT JOIN hc_fct_device_update_registry AS r
    ON p.device_id = r.device_id
   AND r.target_sw_version = a.target_sw_version
  WHERE p.plugged = TRUE
    AND p.battery_level >= 50
    AND r.device_id IS NULL
    AND HOUR(CONVERT_TZ(p.power_status_ts, 'UTC', u.timezone)) BETWEEN 7 AND 18;
END;
