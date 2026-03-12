-- Foundation test data: 5 patients P001–P005 (CDC create events: before=null, after=JSON payload, op='c')
INSERT INTO raw_patients (patient_id, before, after, op, source_ts_ms)
SELECT patient_id, before, after, op, source_ts_ms
FROM (VALUES
  ('P001', CAST(NULL AS STRING), '{"patient_id":"P001","name":"Alice Smith","gender":"F","birth_date":"1980-05-15","zip_code":"15201"}', 'c', 1710000000000),
  ('P002', CAST(NULL AS STRING), '{"patient_id":"P002","name":"Bob Jones","gender":"M","birth_date":"1975-11-22","zip_code":"15202"}', 'c', 1710000000000),
  ('P003', CAST(NULL AS STRING), '{"patient_id":"P003","name":"Carol Lee","gender":"F","birth_date":"1990-03-08","zip_code":"15203"}', 'c', 1710000000000),
  ('P004', CAST(NULL AS STRING), '{"patient_id":"P004","name":"David Kim","gender":"M","birth_date":"1985-07-30","zip_code":"15204"}', 'c', 1710000000000),
  ('P005', CAST(NULL AS STRING), '{"patient_id":"P005","name":"Eve Brown","gender":"F","birth_date":"1978-01-12","zip_code":"15205"}', 'c', 1710000000000)
) AS data(patient_id, before, after, op, source_ts_ms);
