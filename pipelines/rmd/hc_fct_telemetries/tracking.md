## Fact tables: telemetry analytics (hc_fct_telemetries folder)

This folder defines three windowed fact tables:

1. **hc_fct_telemetry_1h** – 1h tumbling window aggregates per device/patient/metric (avg, min, max, count).
2. **hc_fct_telemetry_5m** – 5m tumbling window aggregates per device/patient/metric.
3. **hc_fct_compliance_1h** – 1h compliance per device/patient/metric: readings_in_range, readings_total, compliance_pct (join telemetry with prescriptions).

All use processing-time windowing (PROCTIME) so no watermark is required on the source.

Status date:

Context:

-- Process file: 

## DDL and DML for fact table status

* DDL:
* DML:

STATUS: MIGRATED

## Direct Dependencies found



## Tests

* Get source data from <> -> 
* Verify there is no duplicate in output table  ->