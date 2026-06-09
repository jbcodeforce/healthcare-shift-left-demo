SELECT event_id, route_reason
FROM hc_fct_device_alert
WHERE event_id = 'evt-btn-second' AND route_reason = 'EMERGENCY';
