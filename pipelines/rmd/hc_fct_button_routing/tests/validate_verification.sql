SELECT event_id, route_reason
FROM hc_fct_device_verification
WHERE event_id = 'evt-btn-first' AND route_reason = 'VERIFICATION';
