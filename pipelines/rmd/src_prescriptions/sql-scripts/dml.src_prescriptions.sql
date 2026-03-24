-- One row per parameter object from the parameters JSON array.
-- Source table must have a VARCHAR column `parameters` containing a JSON array of objects, e.g.:
-- [{"parameter_name":"Pressure","parameter_tolerance":1.0,"parameter_type":"float","parameter_value":10.0}, ...]
--
-- Uses JSON_QUERY(parameters, 'lax $[*]' RETURNING ARRAY<STRING>) to get one JSON object string per
-- element, then UNNEST to one row per element, then JSON_VALUE to extract fields.
INSERT INTO hc_src_prescriptions
SELECT
  prescription_id,
  patient_id,
  device_id,
  medication_or_therapy,
  JSON_VALUE(param_obj, 'lax $.parameter_name')     AS metric_name,
  CAST(JSON_VALUE(param_obj, 'lax $.parameter_value' RETURNING STRING) AS DOUBLE) AS target_value,
  CAST(JSON_VALUE(param_obj, 'lax $.parameter_tolerance' RETURNING STRING) AS DOUBLE) AS tolerance_range,
  TO_TIMESTAMP_LTZ(start_date) AS start_date,
  TO_TIMESTAMP_LTZ(end_date) AS end_date
FROM `healthcare.public.prescriptions`
CROSS JOIN UNNEST(
  JSON_QUERY(parameters, 'lax $[*]' RETURNING ARRAY<STRING>)
) AS t(param_obj)
WHERE parameters IS NOT NULL AND TRIM(parameters) <> '' AND TRIM(parameters) <> '[]';
