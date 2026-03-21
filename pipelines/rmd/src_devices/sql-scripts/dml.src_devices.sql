INSERT INTO hc_src_devices
SELECT 
    device_id,
    patient_id,
    model_type,
    manufacturer,
    serial_number,
    software_version,
    pressure_setting,
    flow_rate_setting,
    flow_level_setting
FROM hc_raw_devices
WHERE patient_id IS NOT NULL