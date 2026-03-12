-- Foundation test data: 5 patients, 1 device per patient, 3 metrics each (Pressure, FlowRate, MotorSpeed)
INSERT INTO `device_metrics` (device_id, patient_id, ts, metric_name, metric_value, software_version)
SELECT device_id, patient_id, ts, metric_name, metric_value, software_version
FROM (VALUES
  ('DEV-P001', 'P001', 1710000000000, 'Pressure',    10.5, '1.2.0'),
  ('DEV-P001', 'P001', 1710000000000, 'FlowRate',     2.5, '1.2.0'),
  ('DEV-P001', 'P001', 1710000000000, 'MotorSpeed', 3200.0, '1.2.0'),
  ('DEV-P002', 'P002', 1710000000000, 'Pressure',    11.0, '1.2.0'),
  ('DEV-P002', 'P002', 1710000000000, 'FlowRate',     2.3, '1.2.0'),
  ('DEV-P002', 'P002', 1710000000000, 'MotorSpeed', 3100.0, '1.2.0'),
  ('DEV-P003', 'P003', 1710000000000, 'Pressure',     9.8, '1.2.0'),
  ('DEV-P003', 'P003', 1710000000000, 'FlowRate',     2.6, '1.2.0'),
  ('DEV-P003', 'P003', 1710000000000, 'MotorSpeed', 3300.0, '1.2.0'),
  ('DEV-P004', 'P004', 1710000000000, 'Pressure',    10.2, '1.2.0'),
  ('DEV-P004', 'P004', 1710000000000, 'FlowRate',     2.4, '1.2.0'),
  ('DEV-P004', 'P004', 1710000000000, 'MotorSpeed', 3150.0, '1.2.0'),
  ('DEV-P005', 'P005', 1710000000000, 'Pressure',    10.0, '1.2.0'),
  ('DEV-P005', 'P005', 1710000000000, 'FlowRate',     2.5, '1.2.0'),
  ('DEV-P005', 'P005', 1710000000000, 'MotorSpeed', 3250.0, '1.2.0')
);
