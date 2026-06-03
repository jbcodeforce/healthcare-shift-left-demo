INSERT INTO hc_src_patients
WITH normalized AS (
  SELECT
    coalesce(if(op = 'd', json_value(before, '$.patient_id'), json_value(after, '$.patient_id') ), 'dummy_patient_id') AS patient_id,
    coalesce(if(op = 'd', json_value(before, '$.name'), json_value(after, '$.name')), 'dummy_name') AS name,
    coalesce(if(op = 'd', json_value(before, '$.gender'), json_value(after, '$.gender')), 'dummy_gender') AS gender,
    coalesce(if(op = 'd', json_value(before, '$.birth_date'), json_value(after, '$.birth_date')), 'dummy_birth_date') AS birth_date,
    coalesce(if(op = 'd', json_value(before, '$.zip_code'), json_value(after, '$.zip_code')), 'dummy_zip_code') AS zip_code,
    coalesce(if(op = 'd', json_value(before, '$.timezone'), json_value(after, '$.timezone')), 'America/Chicago') AS timezone,
    source_ts_ms,
    op
  FROM hc_raw_patients
),
deduped AS (
  SELECT
    patient_id,
    name,
    gender,
    birth_date,
    zip_code,
    timezone,
    source_ts_ms,
    op,
    ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY source_ts_ms ASC) AS rn
  FROM normalized
)

SELECT patient_id, name, gender, birth_date, zip_code, timezone, source_ts_ms, op
FROM deduped
WHERE rn = 1