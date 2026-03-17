## Fact Table: hc_fct_drift_evts

Status date:

Context: Drift alerting. Joins `hc_device_metrics` (observed telemetry) with `hc_src_prescriptions` (target ± tolerance). Emits one row per reading outside range; optional prescription validity window (start_date/end_date).

-- Process file: 

## DDL and DML for fact table status

* DDL:
* DML:

STATUS: MIGRATED

## Direct Dependencies found



## Tests

* Get source data from <> -> 
* Verify there is no duplicate in output table  ->