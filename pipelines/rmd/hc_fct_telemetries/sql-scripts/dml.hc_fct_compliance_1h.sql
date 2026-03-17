-- 1-hour compliance: in-range vs total readings and compliance_pct per device/patient/metric.
-- Joins telemetry with prescriptions (target ± tolerance), then tumbling 1h window.
INSERT INTO hc_fct_compliance_1h
SELECT
  TUMBLE_START(proc, INTERVAL '1' HOUR) AS window_start,
  TUMBLE_END(proc, INTERVAL '1' HOUR)   AS window_end,
  device_id,
  patient_id,
  metric_name,
  SUM(in_range)                     AS readings_in_range,
  COUNT(*)                          AS readings_total,
  CAST(SUM(in_range) AS DOUBLE) / NULLIF(COUNT(*), 0) * 100 AS compliance_pct
FROM (
  SELECT
    m.device_id,
    m.patient_id,
    m.metric_name,
    CASE
      WHEN m.metric_value BETWEEN p.target_value - COALESCE(p.tolerance_range, 0)
          AND p.target_value + COALESCE(p.tolerance_range, 0)
      THEN 1
      ELSE 0
    END AS in_range,
    PROCTIME() AS proc
  FROM hc_device_metrics m
  JOIN hc_src_prescriptions p
    ON m.device_id = p.device_id
   AND m.patient_id = p.patient_id
   AND m.metric_name = p.metric_name
   AND (p.start_date IS NULL OR m.ts >= p.start_date)
   AND (p.end_date IS NULL OR m.ts <= p.end_date)
)
GROUP BY TUMBLE(proc, INTERVAL '1' HOUR), device_id, patient_id, metric_name;
