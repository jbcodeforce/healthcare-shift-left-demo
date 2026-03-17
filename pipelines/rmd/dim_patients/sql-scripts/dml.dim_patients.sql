insert into hc_dim_patients
with current_info as (
   SELECT
      patient_id,
      device_id,
      param_obj
 FROM `hc_src_prescriptions`
  CROSS JOIN UNNEST(
  JSON_QUERY(parameters, 'lax $[*]' RETURNING ARRAY<STRING>)
) AS t(param_obj)
  WHERE parameters IS NOT NULL AND TRIM(parameters) <> '' AND TRIM(parameters) <> '[]'
),
params as (
SELECT
  patient_id,
  device_id,
  if(JSON_VALUE(param_obj, 'lax $.parameter_name')= 'Pressure',   CAST(JSON_VALUE(param_obj, 'lax $.parameter_value' RETURNING DOUBLE) AS DOUBLE), 0) AS pressure_setting,
  if(JSON_VALUE(param_obj, 'lax $.parameter_name')= 'FlowRate',   CAST(JSON_VALUE(param_obj, 'lax $.parameter_value' RETURNING DOUBLE) AS DOUBLE), 0) AS flow_rate_setting,
  if(JSON_VALUE(param_obj, 'lax $.parameter_name')= 'MotorSpeed',   CAST(JSON_VALUE(param_obj, 'lax $.parameter_value' RETURNING DOUBLE) AS DOUBLE), 0) AS motor_speed
FROM current_info
),
max_value as (select
  patient_id,
  device_id,
  MAX(pressure_setting)   AS pressure_setting,
  MAX(flow_rate_setting)  AS flow_rate_setting,
  MAX(motor_speed)        AS motor_speed,
  CASE
    WHEN MAX(motor_speed) > 3000 THEN 3
    WHEN MAX(motor_speed) > 1000 AND MAX(motor_speed) <= 3000 THEN 2
    ELSE 1
  END AS flow_level
FROM params
GROUP BY patient_id, device_id)
select
  max_value.patient_id,
  p.name,
  p.gender,
  p.birth_date,
  max_value.device_id,
  d.model_type,
  d.serial_number,
  max_value.pressure_setting,
  max_value.flow_rate_setting,
  max_value.flow_level
FROM max_value
JOIN hc_src_patients p ON max_value.patient_id = p.patient_id
JOIN hc_src_devices d ON max_value.device_id = d.device_id