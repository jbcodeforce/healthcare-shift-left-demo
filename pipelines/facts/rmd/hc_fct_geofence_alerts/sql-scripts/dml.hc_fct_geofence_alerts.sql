-- Alert when GPS is outside circular geofence (haversine distance > radius_m).
-- Production: swap for IS_WITHIN_AREA UDF from flink-udfs-catalog when deployed.
INSERT INTO hc_fct_geofence_alerts
SELECT
  a.area_id,
  e.patient_id,
  e.device_id,
  e.lat,
  e.lng,
  e.event_ts,
  e.event_id
FROM hc_raw_device_events AS e
INNER JOIN hc_dim_care_areas AS a
  ON e.patient_id = a.patient_id
WHERE e.event_type = 'GPS'
  AND e.lat IS NOT NULL
  AND e.lng IS NOT NULL
  AND (
    6371000 * ACOS(
      LEAST(
        1.0,
        GREATEST(
          -1.0,
          COS(RADIANS(a.center_lat)) * COS(RADIANS(e.lat))
            * COS(RADIANS(e.lng - a.center_lng))
            + SIN(RADIANS(a.center_lat)) * SIN(RADIANS(e.lat))
        )
      )
    )
  ) > a.radius_m;
