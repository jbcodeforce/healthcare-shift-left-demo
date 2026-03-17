-- 5-minute tumbling window: aggregates per device/patient/metric.
-- Uses processing-time windowing so no watermark is required on the source.
INSERT INTO hc_fct_telemetry_5m
SELECT
  TUMBLE_START(proc, INTERVAL '5' MINUTE) AS window_start,
  TUMBLE_END(proc, INTERVAL '5' MINUTE)   AS window_end,
  device_id,
  patient_id,
  metric_name,
  AVG(metric_value)  AS avg_value,
  MIN(metric_value)  AS min_value,
  MAX(metric_value)  AS max_value,
  COUNT(*)           AS count_reading
FROM (
  SELECT device_id, patient_id, metric_name, metric_value,
         PROCTIME() AS proc
  FROM hc_device_metrics
)
GROUP BY TUMBLE(proc, INTERVAL '5' MINUTE), device_id, patient_id, metric_name;
