-- Foundation test data: one prescription per patient P001–P005 (CDC create events: before=null, after=row, op='c')
INSERT INTO raw_prescriptions (prescription_id, before, after, op, source_ts_ms)
VALUES
  ('RX-P001', NULL, ROW('RX-P001', 'P001', 'DEV-P001', 'CPAP Oxygen Flow', 'Pressure', 10.5, 0.5, 1710000000000, 1715000000000), 'c', 1710000000000),
  ('RX-P002', NULL, ROW('RX-P002', 'P002', 'DEV-P002', 'CPAP Oxygen Flow', 'Pressure', 11.0, 0.5, 1710000000000, 1715000000000), 'c', 1710000000000),
  ('RX-P003', NULL, ROW('RX-P003', 'P003', 'DEV-P003', 'CPAP Oxygen Flow', 'Pressure',  9.8, 0.5, 1710000000000, 1715000000000), 'c', 1710000000000),
  ('RX-P004', NULL, ROW('RX-P004', 'P004', 'DEV-P004', 'CPAP Oxygen Flow', 'Pressure', 10.2, 0.5, 1710000000000, 1715000000000), 'c', 1710000000000),
  ('RX-P005', NULL, ROW('RX-P005', 'P005', 'DEV-P005', 'CPAP Oxygen Flow', 'Pressure', 10.0, 0.5, 1710000000000, 1715000000000), 'c', 1710000000000);
