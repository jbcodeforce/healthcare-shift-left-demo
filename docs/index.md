# Introduction

## Goals

The scope of this repository is to build an end-to-end Flink, Kafka, Lake house healthcare demonstration, starting from Debezium CDC to Confluent Cloud Kafka, Flink SQL to process Raw->Bronze->Silver->Gold records, to sink s3 parquet/iceberg tables.

The approach is to use healthcare use case, like Patient records, health providers, prescriptions and device management. 

The demonstration illustrates two main use cases:
1. device monitoring and compliance to a doctor's prescription. This is a basic domain model but representing enough foundations to present different real-time processing use cases. We use Flink to compare Command/Intent (The Prescription) against Reality (The Telemetry). 
1. Device management, specically software version management, first button action, and geofence.

The audiance of this demonstration is data engineers to understand the art of feaseable. 

## Table of Content

* [Demonstration Architecture](#architecture)
* [Use Cases](#use-cases)
* [Demonstration Script](./demonstration_script.md)
* [Implementation Approach](./dev_instructions.md)

## Architecture

### Pipelines Architecture

The figure below presents the production deployment of data streaming pipelines from processing raw data to silver and gold records. The pipeline processing is done using Confluent Cloud Flink SQL queries. 

<figure markdown="span">
![](./images/pipeline-view.drawio.png)
<caption>**Figure 1: Classical Medallion with flink**</caption>
</figure>

In this demonstration only `Prescription` entities are using CDC. The landing zone represents the raw data, while a first layer of Flink processing helps to prepare silver data, with deduplication, schema transformation and filtering.

This diagram also presents a second layer of Flink statements to prepare facts and dimensions as data-as-a-product.

### Demonstration Components

To support this demonstration, the following deployment architecture is defined: 

* The Flink SQL statements and Topics are running in Confluent Cloud. 
* Sink tables used for Lake house platform are saved in parquet format, with Apache Iceberg metadata, in a Cloud Provider object storage layer.
* A webApp supports the demonstration scripts and is also used to present business intelligence dashboards. It runs locally.
* The backend supports producing data to Kafka, writing to a Postgresql database, and exposing APIs for dashboards. It runs locally.
* Debezium CDC Kafka connector is deployed locally to upload change data capture on the `Prescription` tables to Kafka
* Confluent Cloud Flink Compute pool is defined to run the Flink SQL statements

<figure markdown="span">
![](./images/demo_components.drawio.png)
<caption>**Figure 2: Component view**</caption>
</figure>
The green components are for demonstration purpose and will run on your laptop.

Here is an example of the WebApp home page, with a sidebar to navigate into the demonstration steps:
<figure markdown="span">
![](./images/home_page.png)
<caption>**Figure 3: WebApp home page**</caption>
</figure>

### Demonstration Features

* **Control plane** — Vue.js UI and FastAPI backend for patients, devices, prescriptions, simulation, and live telemetry (SSE → Kafka).
* **CDC** — PostgreSQL prescriptions streamed to Confluent via Debezium Kafka Connect.
* **Stream processing** — Flink SQL pipelines (raw → RMD facts/dimensions); deploy with shift-left or dbt (see [Quick Start](./quick_start.md)).
* **Analytics** — Dashboard backed by local Parquet samples or S3 via Tableflow ([IaC README](../IaC/README.md#tableflow-and-s3)).

Component-level setup and extension notes: [Developer Instructions](./dev_instructions.md#understanding-the-main-components).

## Use Cases

### Building golden records

As part of moving from batch to real-time processing the following dimensions and facts can be created. Dimensions are static/slow-moving context (who/what/where), facts are events with timestamps and additive measures.

| Dim/Fact | Explanation | Reference |
|-------|-------------|-----------|
| **dim_patients** | one row per patient (with device and current prescription-derived settings: pressure, flow rate, flow level | [dml.dim_patients.sql](https://github.com/jbcodeforce/healthcare-shift-left-demo/tree/main/pipelines/rmd/dim_patients/sql-scripts/dml.dim_patients.sql) | 
| **fact_drift_events** | Assess devise metric vs prescription, one row per drift alert  | [dml.hc_fct_drift_evts.sql](https://github.com/jbcodeforce/healthcare-shift-left-demo/tree/main/pipelines/rmd/hc_fct_drift_evts/sql-scripts/dml.hc_fct_drift_evts.sql) |
| **Telemetry Facts** | fact_telemetry_1h: windowed aggregates per device/patient/metric. fact_compliance_1h: in-range vs total readings (and optionally compliance_pct) per window. | [dml.hc_fct_telemetry_1h.sql](https://github.com/jbcodeforce/healthcare-shift-left-demo/tree/main/pipelines/rmd/hc_fct_telemetries/sql-scripts/dml.hc_fct_telemetry_1h.sql) |
| **Anomaly Detection** | Fact table to compute anomaly on Pressure, FlowRate or FlowLevel | [hc_fct_dev_anomaly.sql](https://github.com/jbcodeforce/healthcare-shift-left-demo/tree/main/pipelines/rmd/hc_fct_dev_anomaly/sql-scripts/dml.hc_fct_dev_anomaly.sql) |
| **BBH device events** | Button routing, geofence, enrichment, DQ, OTA (Best Buy Health patterns) | [pipelines/rmd/README.md](../pipelines/rmd/README.md) |

To study how those facts are created, [see these explanations](./demonstration_script.md).


### Compliance Alerting

Use a join between the Prescription stream with the DeviceTelemetry stream to check for **Prescription Drift**.
The prescriptions change rarely. If DeviceTelemetry.metricValue is outside the Prescription.targetValue +/- toleranceRange for more than X minutes, trigger an alert.
The sink persits alerts in a new Kafka topic: `alerts.compliance.non-adherence`.

### Device's health

With the Device telemetry web page, user can simulate Pressure, flowRate or flowlevel defect. Starting the simulation sends messages to the `hc_raw_device_metrics` topic, for all the 5 devices of the demonstration.

<figure markdown="span">
![](./images/start_simul_metrics.png)
<caption>**Figure 4: Metrics simulation**</caption>
</figure>

Once the simulation is running, the user can select one of the device and apply one of the 3 simulation.

An [anomaly detection](https://docs.confluent.io/cloud/current/ai/builtin-functions/detect-anomalies.html#ml-detect-anomalies) query can assess the three metrics and report potential issue.

### First Button Press

Device has an emergency button that user can press. For device initiation, the users press the emergency button the first time to verify operation – not call for help. After that a press to the emergency button is an alert. This is supported by processing device_events. The following tables/topics are supporting this use case:

| Table | location | Purpose |
| ----- | -------- |---------|
| hc_raw_device_events | [raw_device_events](https://github.com/jbcodeforce/healthcare-shift-left-demo/tree/main/pipelines/raw/raw_device_events) | Get raw device events. Events have a type that can drive different rules and processing |
| hc_raw_device_assignments | [device_assignments]() | Device to user assignment |
| hc_fct_assignment_verification_registry | [assignment_verification_registry]() | Assess if this is a first button press and keep it as a fact |
| hc_button_press_enriched | []() | |
| hc_device_verification | []() | |
| fc_device_alert | []() | |


### Geofence Crossing

For users at risk of wandering off, we allow caregivers to provide geofences.  When a GPS coordinate is outside the geofence, we can alert the caregivers. This implementation can leverage the UDFs  named [geo-distance](https://github.com/jbcodeforce/flink-udfs-catalog/tree/main/geo_distance) and [within-area](https://github.com/jbcodeforce/flink-udfs-catalog/tree/main/within_area).

### Device management

Update software firmware for allowed device. This is like implementing a statge machine for each device. 

* From the device events we should be able to assess the devices most recent power status event, indicating they are on their charger and at least 50% charged.
* The current time in the user's time zone is during daylight hour
* The device has not already been updated.

State machine (one update per device + target firmware version):

```text
WAITING ──(on allowlist + charger + battery>=50)──► CHARGING_READY
CHARGING_READY ──(local daylight hour)──► UPDATE_PENDING
UPDATE_PENDING ──(command emitted)──► UPDATED (terminal)
WAITING ◄──(removed from allowlist or unplugged)── CHARGING_READY
```

* `WAITING`: device not eligible or power preconditions not met.
* `CHARGING_READY`: allowlisted, latest power status on charger and ≥50%, not yet daylight locally.
* `UPDATE_PENDING`: all preconditions met; Flink emits one command.
* `UPDATED`: registry row prevents duplicate commands for the same `(imei, target_sw_version)`.

* Re-evaluation is driven by each incoming `POWER_STATUS` event. A device that becomes eligible overnight is picked up on the next power event after local daylight begins (or add a scheduled re-scan statement if sub-hour latency is required).
* Registry PK `(imei, target_sw_version)` gives a new verification cycle when ops bumps `target_sw_version` on the allowlist.


### Other extensions

Goal assess device reliability:

* Windowed Aggregation: Calculate the average Pressure level or rate flow over a 1-hour tumbling window.
* Pattern Recognition: If the Pressure increases by $>10% over three consecutive windows while FlowRate remains constant, the device may have a clogged filter.

If we do an insulin pump, we can have Flink detecting a spike in BloodGlucose (Telemetry). Then checks the Prescription for the maximum allowable dose, to finally sends a command back to a Kafka topic `device.commands` to trigger an insulin bolus automatically.

## Resources

* [Confluent Cloud Flink product documentation](https://docs.confluent.io/cloud/current/flink/overview.html)
* [Guide for Apache Flink and Confluent Flink products](https://jbcodeforce.github.io/flink-studies/)
* [Shift left utils for preparing the Flink SQL project and manage it](https://jbcodeforce.github.io/shift_left_utils)