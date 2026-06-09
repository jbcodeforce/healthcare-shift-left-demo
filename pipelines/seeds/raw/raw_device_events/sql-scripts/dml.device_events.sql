-- Foundation test data for button press, power status, and GPS scenarios.
INSERT INTO hc_raw_device_events
(event_id, device_id, patient_id, event_type, lng, lat, battery_level, plugged, hw_model, sw_version, event_ts)
VALUES
  ('evt-btn-001', 'DEV-P001', 'P001', 'BUTTON_PRESSED', NULL, NULL, NULL, NULL, 'RMD-100', '1.2.0', TIMESTAMP '2024-06-15 14:00:00'),
  ('evt-pwr-001', 'DEV-P001', 'P001', 'POWER_STATUS', NULL, NULL, 75, TRUE, 'RMD-100', '1.2.0', TIMESTAMP '2024-06-15 14:05:00'),
  ('evt-gps-001', 'DEV-P001', 'P001', 'GPS', -79.995, 40.441, NULL, NULL, 'RMD-100', '1.2.0', TIMESTAMP '2024-06-15 14:10:00'),
  ('evt-gps-002', 'DEV-P002', 'P002', 'GPS', -80.050, 40.500, NULL, NULL, 'RMD-100', '1.2.0', TIMESTAMP '2024-06-15 14:10:00');
