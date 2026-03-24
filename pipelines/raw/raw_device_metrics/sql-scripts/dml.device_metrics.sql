-- Foundation test data: 5 patients, 1 device per patient, 3 metrics each (Pressure, FlowRate, FlowLevel)
INSERT INTO hc_raw_device_metrics (device_id, patient_id, ts, metric_name, metric_value, software_version)
(VALUES
  ('DEV-P001', 'P001', TIMESTAMP '2024-03-09 18:40:00', 'Pressure',    10.5, '1.2.0'),
  ('DEV-P001', 'P001', TIMESTAMP '2024-03-09 18:40:00', 'FlowRate',     2.5, '1.2.0'),
  ('DEV-P001', 'P001', TIMESTAMP '2024-03-09 18:40:00', 'FlowLevel', 60.0, '1.2.0'),
  ('DEV-P002', 'P002', TIMESTAMP '2024-03-09 18:40:00', 'Pressure',    11.0, '1.2.0'),
  ('DEV-P002', 'P002', TIMESTAMP '2024-03-09 18:40:00', 'FlowRate',     2.3, '1.2.0'),
  ('DEV-P002', 'P002', TIMESTAMP '2024-03-09 18:40:00', 'FlowLevel', 60.0, '1.2.0'),
  ('DEV-P003', 'P003', TIMESTAMP '2024-03-09 18:40:00', 'Pressure',     9.8, '1.2.0'),
  ('DEV-P003', 'P003', TIMESTAMP '2024-03-09 18:40:00', 'FlowRate',     2.6, '1.2.0'),
  ('DEV-P003', 'P003', TIMESTAMP '2024-03-09 18:40:00', 'FlowLevel', 60.0, '1.2.0'),
  ('DEV-P004', 'P004', TIMESTAMP '2024-03-09 18:40:00', 'Pressure',    10.2, '1.2.0'),
  ('DEV-P004', 'P004', TIMESTAMP '2024-03-09 18:40:00', 'FlowRate',     2.4, '1.2.0'),
  ('DEV-P004', 'P004', TIMESTAMP '2024-03-09 18:40:00', 'FlowLevel', 60.0, '1.2.0'),
  ('DEV-P005', 'P005', TIMESTAMP '2024-03-09 18:40:00', 'Pressure',    10.0, '1.2.0'),
  ('DEV-P005', 'P005', TIMESTAMP '2024-03-09 18:40:00', 'FlowRate',     2.5, '1.2.0'),
  ('DEV-P005', 'P005', TIMESTAMP '2024-03-09 18:40:00', 'FlowLevel', 60.0, '1.2.0')
);
