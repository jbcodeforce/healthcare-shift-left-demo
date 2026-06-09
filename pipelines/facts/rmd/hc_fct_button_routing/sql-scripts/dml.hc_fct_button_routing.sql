-- First button press routes to verification; later presses route to emergency alert.
EXECUTE STATEMENT SET
BEGIN
  INSERT INTO hc_fct_assignment_verification_registry
  SELECT
    a.assignment_id,
    e.device_id,
    e.patient_id,
    e.event_ts AS first_press_ts,
    e.event_id AS first_event_id
  FROM hc_raw_device_events AS e
  INNER JOIN hc_src_device_assignments AS a
    ON e.device_id = a.device_id
    AND e.patient_id = a.patient_id
    AND a.active = TRUE
  LEFT JOIN hc_fct_assignment_verification_registry AS r
    ON a.assignment_id = r.assignment_id
  WHERE e.event_type = 'BUTTON_PRESSED'
    AND r.assignment_id IS NULL;

  INSERT INTO hc_fct_device_verification
  SELECT
    e.event_id,
    e.device_id,
    e.patient_id,
    a.assignment_id,
    e.event_ts,
    'VERIFICATION' AS route_reason
  FROM hc_raw_device_events AS e
  INNER JOIN hc_src_device_assignments AS a
    ON e.device_id = a.device_id
    AND e.patient_id = a.patient_id
    AND a.active = TRUE
  LEFT JOIN hc_fct_assignment_verification_registry AS r
    ON a.assignment_id = r.assignment_id
  WHERE e.event_type = 'BUTTON_PRESSED'
    AND r.assignment_id IS NULL;

  INSERT INTO hc_fct_device_alert
  SELECT
    e.event_id,
    e.device_id,
    e.patient_id,
    a.assignment_id,
    e.event_ts,
    'EMERGENCY' AS route_reason
  FROM hc_raw_device_events AS e
  INNER JOIN hc_src_device_assignments AS a
    ON e.device_id = a.device_id
    AND e.patient_id = a.patient_id
    AND a.active = TRUE
  INNER JOIN hc_fct_assignment_verification_registry AS r
    ON a.assignment_id = r.assignment_id
  WHERE e.event_type = 'BUTTON_PRESSED';
END;
