-- Drift alerting: emit one row per telemetry reading that falls outside
-- prescription target ± tolerance. Joins device_metrics (observed) with
-- src_prescriptions (desired). Prescription validity window (start_date/end_date)
-- is applied when present.
INSERT INTO hc_fct_drift_evts
SELECT
  m.device_id,
  m.patient_id,
  d.name,
  d.gender,
  d.birth_date,
  m.ts,
  p.prescription_id,
  m.metric_name,
  p.target_value                    AS prescribed_value,
  m.metric_value                    AS actual_value,
  COALESCE(p.tolerance_range, 0)    AS tolerance_range,
  CASE
    WHEN m.metric_value > p.target_value + COALESCE(p.tolerance_range, 0) THEN 'Above range'
    WHEN m.metric_value < p.target_value - COALESCE(p.tolerance_range, 0) THEN 'Below range'
     ELSE 'In range'
  END                               AS drift_direction,
  m.metric_value - p.target_value   AS deviation,
  CONCAT(
    m.metric_name,
    ' ',
    CASE
      WHEN m.metric_value > p.target_value + COALESCE(p.tolerance_range, 0) THEN 'above'
      ELSE 'below'
    END,
    ' range (prescribed ',
    CAST(p.target_value AS STRING),
    ' ± ',
    CAST(COALESCE(p.tolerance_range, 0) AS STRING),
    ', actual ',
    CAST(m.metric_value AS STRING),
    ')'
  ) AS message
FROM hc_raw_device_metrics m
LEFT JOIN hc_dim_patients d
  ON m.patient_id = d.patient_id
LEFT JOIN hc_src_prescriptions p
  ON m.device_id = p.device_id
 AND m.patient_id = p.patient_id
 AND m.metric_name = p.metric_name
WHERE (
  m.metric_value > p.target_value + COALESCE(p.tolerance_range, 0)
  OR m.metric_value < p.target_value - COALESCE(p.tolerance_range, 0)
)
AND (p.start_date IS NULL OR m.ts >= p.start_date)
AND (p.end_date IS NULL OR m.ts <= p.end_date);
