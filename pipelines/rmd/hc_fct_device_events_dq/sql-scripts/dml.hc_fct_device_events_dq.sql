EXECUTE STATEMENT SET
BEGIN
  INSERT INTO hc_dim_cell_tower_zones
  (zone_id, zone_name, min_lat, max_lat, min_lng, max_lng)
  VALUES
    ('CT-PGH-01', 'Downtown cell tower fallback', 40.435, 40.445, -80.005, -79.990),
    ('CT-PGH-02', 'East side cell tower fallback', 40.448, 40.458, -79.940, -79.925);

  INSERT INTO hc_fct_device_events_dq
  SELECT event_id, device_id, patient_id, event_type, event_ts, dq_reason
  FROM (
    SELECT
      e.event_id,
      e.device_id,
      e.patient_id,
      e.event_type,
      e.event_ts,
      'BAD_TIMESTAMP' AS dq_reason
    FROM hc_raw_device_events AS e
    WHERE e.event_ts < TIMESTAMP '2020-01-01 00:00:00'
       OR e.event_ts > CURRENT_TIMESTAMP + INTERVAL '1' DAY
    UNION ALL
    SELECT
      e.event_id,
      e.device_id,
      e.patient_id,
      e.event_type,
      e.event_ts,
      'CELL_TOWER_GPS' AS dq_reason
    FROM hc_raw_device_events AS e
    INNER JOIN hc_dim_cell_tower_zones AS z
      ON e.event_type = 'GPS'
     AND e.lat BETWEEN z.min_lat AND z.max_lat
     AND e.lng BETWEEN z.min_lng AND z.max_lng
    UNION ALL
    SELECT
      e.event_id,
      e.device_id,
      e.patient_id,
      e.event_type,
      e.event_ts,
      'LAT_OUT_OF_RANGE' AS dq_reason
    FROM hc_raw_device_events AS e
    WHERE e.lat IS NOT NULL AND (e.lat < -90 OR e.lat > 90)
    UNION ALL
    SELECT
      e.event_id,
      e.device_id,
      e.patient_id,
      e.event_type,
      e.event_ts,
      'LNG_OUT_OF_RANGE' AS dq_reason
    FROM hc_raw_device_events AS e
    WHERE e.lng IS NOT NULL AND (e.lng < -180 OR e.lng > 180)
    UNION ALL
    SELECT
      e.event_id,
      e.device_id,
      e.patient_id,
      e.event_type,
      e.event_ts,
      'BATTERY_OUT_OF_RANGE' AS dq_reason
    FROM hc_raw_device_events AS e
    WHERE e.battery_level IS NOT NULL
      AND (e.battery_level < 0 OR e.battery_level > 100)
  ) AS flagged;
END;
