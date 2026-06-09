# RMD Pipelines — HealthCare  Use Cases

Flink SQL pipelines implementing some HealthCare analysis use cases on top of the healthcare shift-left demo domain.

## Architecture

```text
Backend simulator
    └── hc_raw_device_events (BUTTON_PRESSED, POWER_STATUS, GPS)
            ├── hc_fct_button_routing → verification | alert
            ├── hc_fct_geofence_alerts
            ├── hc_fct_device_events_enriched
            ├── hc_fct_device_events_dq
            └── hc_fct_device_ota → power_latest | update_commands | registry

Dimensions (backend-seeded Kafka upsert topics):
    hc_src_device_assignments, hc_dim_care_areas, hc_src_device_update_allowlist
    hc_src_patients (+ timezone), hc_src_devices
```

## Pipeline catalog

| Use case | Folder | Sink topic(s) | Upstream |
|---|---|---|---|
| First button press | `hc_fct_button_routing/` | `hc_fct_device_verification`, `hc_fct_device_alert`, `hc_fct_assignment_verification_registry` | `hc_raw_device_events`, `hc_src_device_assignments` |
| Geofence crossing | `hc_fct_geofence_alerts/` | `hc_fct_geofence_alerts` | `hc_raw_device_events`, `hc_dim_care_areas` |
| Message enrichment | `hc_fct_device_events_enriched/` | `hc_fct_device_events_enriched` | `hc_raw_device_events`, `hc_src_patients`, `hc_src_devices` |
| Data quality | `hc_fct_device_events_dq/` | `hc_fct_device_events_dq`, `hc_dim_cell_tower_zones` | `hc_raw_device_events` |
| Device OTA | `hc_fct_device_ota/` | `hc_fct_device_power_latest`, `hc_fct_device_update_commands`, `hc_fct_device_update_registry` | `hc_raw_device_events`, allowlist, assignments, patients |
| Anomaly detection | `hc_fct_dev_anomaly/` (existing) | `hc_fct_dev_anomaly` | `hc_raw_device_metrics` |

Raw source: `pipelines/raw/raw_device_events/` → `hc_raw_device_events`.

## State machines

### Button press routing

```text
WAITING ──(first BUTTON_PRESSED for assignment)──► VERIFICATION
VERIFICATION ──(registry write)──► UPDATED for assignment
UPDATED ──(subsequent presses)──► EMERGENCY alert
```

New assignment after device reassignment resets to VERIFICATION path (registry keyed by `assignment_id`).

### Device OTA

```text
WAITING ──(allowlist + charger + battery>=50)──► CHARGING_READY
CHARGING_READY ──(local daylight hour)──► UPDATE_PENDING
UPDATE_PENDING ──(command emitted)──► UPDATED (terminal)
```

Registry PK: `(device_id, target_sw_version)`.

## Backend demo API

After starting the backend with Kafka configured:

```bash
# First button press (verification path)
curl -X POST http://localhost:8000/device/DEV-P001/events/button-press

# Second press (emergency path, after registry populated)
curl -X POST http://localhost:8000/device/DEV-P001/events/button-press

# OTA eligibility (power status during daylight, America/Chicago)
curl -X POST http://localhost:8000/device/DEV-P001/events/power-status \
  -H 'Content-Type: application/json' \
  -d '{"battery_level": 80, "plugged": true}'

# GPS inside / outside geofence
curl -X POST http://localhost:8000/device/DEV-P001/events/gps \
  -H 'Content-Type: application/json' \
  -d '{"inside_geofence": false}'

# All scenarios for every device
curl -X POST http://localhost:8000/device-events/simulate-all
```

Dimensions (assignments, geofences, OTA allowlist) seed automatically on backend startup.

## Geofence UDF (production)

The demo uses haversine SQL in `hc_fct_geofence_alerts`. For production geofences, deploy `IS_WITHIN_AREA` from [flink-udfs-catalog/within_area](https://github.com/jbcodeforce/flink-udfs-catalog/tree/main/within_area) and replace the distance predicate in `dml.hc_fct_geofence_alerts.sql`.

## Deploy

All pipelines are registered in `pipelines/inventory.json`. Deploy via Terraform:

```bash
cd IaC/flink-statements && terraform apply
```

Or per-pipeline Make targets (requires Confluent CLI):

```bash
cd pipelines/rmd/hc_fct_button_routing && make create_hc_fct_button_routing
```

Order: raw DDL → rmd DDL (including dimensions) → raw DML → rmd DML.

## Tests

Shift-left test fixtures:

- `hc_fct_button_routing/tests/` — first press → verification; second → alert
- `hc_fct_device_ota/tests/` — charger + daylight → command; registry blocks repeat

See `hc_fct_drift_evts/tests/` for the test runner format (`test_definitions.yaml`).

## Related docs

- [Demo index](../../docs/index.md)
- [Anomaly detection](./hc_fct_dev_anomaly/) — existing `ML_DETECT_ANOMALIES` on device metrics
