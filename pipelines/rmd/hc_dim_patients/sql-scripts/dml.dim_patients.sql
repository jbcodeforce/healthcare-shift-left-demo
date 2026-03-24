-- Latest prescription per (patient_id, device_id): max start_date, then max end_date
-- (NULL end_date sorts as start_date via COALESCE), then max prescription_id.
-- Metrics Pressure / FlowRate / FlowLevel only; enrich with hc_src_patients and hc_src_devices.
INSERT INTO hc_dim_patients
WITH rx AS (
  SELECT
    prescription_id,
    patient_id,
    device_id,
    metric_name,
    target_value,
    start_date,
    end_date
  FROM hc_src_prescriptions
  WHERE metric_name IN ('Pressure', 'FlowRate', 'FlowLevel')
),
max_start AS (
  SELECT
    patient_id,
    device_id,
    MAX(start_date) AS max_start
  FROM rx
  GROUP BY patient_id, device_id
),
rx1 AS (
  SELECT r.*
  FROM rx r
  INNER JOIN max_start m
    ON r.patient_id = m.patient_id
   AND r.device_id = m.device_id
   AND r.start_date = m.max_start
),
max_end AS (
  SELECT
    patient_id,
    device_id,
    MAX(COALESCE(end_date, start_date)) AS max_end_key
  FROM rx1
  GROUP BY patient_id, device_id
),
rx2 AS (
  SELECT r.*
  FROM rx1 r
  INNER JOIN max_end e
    ON r.patient_id = e.patient_id
   AND r.device_id = e.device_id
   AND COALESCE(r.end_date, r.start_date) = e.max_end_key
),
latest_rx AS (
  SELECT
    patient_id,
    device_id,
    MAX(prescription_id) AS prescription_id
  FROM rx2
  GROUP BY patient_id, device_id
),
rx_latest_rows AS (
  SELECT r.*
  FROM rx r
  INNER JOIN latest_rx l
    ON r.patient_id = l.patient_id
   AND r.device_id = l.device_id
   AND r.prescription_id = l.prescription_id
),
pivoted AS (
  SELECT
    patient_id,
    device_id,
    MAX(CASE WHEN metric_name = 'Pressure' THEN target_value END) AS prescription_pressure,
    MAX(CASE WHEN metric_name = 'FlowRate' THEN target_value END) AS prescription_flow_rate,
    MAX(CASE WHEN metric_name = 'FlowLevel' THEN CAST(target_value AS INT) END) AS prescription_flow_level
  FROM rx_latest_rows
  GROUP BY patient_id, device_id
)
SELECT
  pivoted.patient_id,
  p.name,
  p.gender,
  p.birth_date,
  pivoted.device_id,
  d.model_type,
  d.device_id,
  d.pressure_setting AS device_pressure,
  d.flow_rate_setting AS device_flow_rate,
  d.flow_level_setting AS device_flow_level,
  pivoted.prescription_pressure,
  pivoted.prescription_flow_rate,
  pivoted.prescription_flow_level
FROM pivoted
INNER JOIN hc_src_patients p ON pivoted.patient_id = p.patient_id
INNER JOIN hc_src_devices d
  ON pivoted.patient_id = d.patient_id
 AND pivoted.device_id = d.device_id;
