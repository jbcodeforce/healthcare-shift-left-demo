-- Message enrichment: join device events with patient and device dimensions (Kafka lookup pattern).
INSERT INTO hc_fct_device_events_enriched
SELECT
  e.event_id,
  e.device_id,
  e.patient_id,
  e.event_type,
  e.event_ts,
  p.name AS patient_name,
  p.zip_code,
  p.timezone,
  d.model_type,
  d.serial_number,
  COALESCE(e.sw_version, d.software_version) AS software_version
FROM hc_raw_device_events AS e
INNER JOIN hc_src_patients AS p
  ON e.patient_id = p.patient_id
INNER JOIN hc_src_devices AS d
  ON e.device_id = d.device_id
 AND e.patient_id = d.patient_id;
