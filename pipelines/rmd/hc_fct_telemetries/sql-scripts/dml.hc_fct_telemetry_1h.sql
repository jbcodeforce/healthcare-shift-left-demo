-- 1-hour tumbling window: aggregates per device/patient/metric.
-- Uses processing-time windowing so no watermark is required on the source.
INSERT INTO hc_fct_telemetry_1h
SELECT
  window_start,
  window_end,
  device_id,
  patient_id,
  metric_name,
  AVG(metric_value)  AS avg_value,
  MIN(metric_value)  AS min_value,
  MAX(metric_value)  AS max_value,
  COUNT(*)           AS count_reading
FROM
  table (
      TUMBLE(
        TABLE hc_raw_device_metrics,
        DESCRIPTOR(ts),
        INTERVAL '1' HOUR
      )
  )
group by window_start, window_end, device_id, patient_id, metric_name;