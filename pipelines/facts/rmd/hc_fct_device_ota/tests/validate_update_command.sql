SELECT command_id, route_reason, target_sw_version
FROM hc_fct_device_update_commands
WHERE device_id = 'DEV-P001' AND route_reason = 'DAYLIGHT_CHARGER_READY';
