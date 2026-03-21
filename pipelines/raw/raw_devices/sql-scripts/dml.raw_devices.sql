-- Foundation test data: 5 patients P001–P005, 1 device per patient
INSERT INTO hc_raw_devices (
  device_id, model_type, manufacturer, serial_number, software_version,
  created_at, updated_at, patient_id, pressure_setting, flow_rate_setting, flow_level_setting
)
VALUES
  ('DEV-P001', 'CPAP-Pro', 'Acme Medical', 'SN001', '1.2.0', 1710000000000, 1710000000000, 'P001', 10.5, 2.5, 60),
  ('DEV-P002', 'CPAP-Pro', 'Acme Medical', 'SN002', '1.2.0', 1710000000000, 1710000000000, 'P002', 11.0, 2.3, 60),
  ('DEV-P003', 'CPAP-Pro', 'Acme Medical', 'SN003', '1.2.0', 1710000000000, 1710000000000, 'P003',  9.8, 2.6, 60),
  ('DEV-P004', 'CPAP-Pro', 'Acme Medical', 'SN004', '1.2.0', 1710000000000, 1710000000000, 'P004', 10.2, 2.4, 60),
  ('DEV-P005', 'CPAP-Pro', 'Acme Medical', 'SN005', '1.2.0', 1710000000000, 1710000000000, 'P005', 10.0, 2.5, 60),
  ('DEV-P005', 'CPAP-Pro', 'Acme Medical', 'SN005', '1.2.0', 1710000000000, 1773473539, 'P005', 10.0, 2.5, 60); -- demonstrate deduplication