# Healthcare Data Streaming Processing Demonstration

Created 03/10/2026 - Updated 04/09/2026

## Updates

* **June 2026:** add [device management and geo distance use cases]()

## Goals

The scope of this repository is to build end-to-end healthcare doman demonstrations, starting from Debezium CDC to Confluent Cloud Kafka, Flink SQL to process Raw->Bronze->Silver->Gold records, to sink s3 parquet/iceberg tables.

![](./docs/images/pipeline-view.drawio.png)

The approach is to use healthcare use cases, like Patient records, health provider, prescriptions and device management. 

![](./docs/images/start_simul_metrics.png)

**The demonstration illustrates:**
* device metrics monitoring and compliance to a doctor's prescription. With the basic domain model but representing good foundations to present different real-time processing use cases. We use Flink to compare Command/Intent (The Prescription) against Reality (The Telemetry). 
* Patient alert: some device may have urgent care button, so one use case addresses 
* Geofence: device getting out of care area.
* Device management: implement a state machine per device to assess when to update firmware


The audiance of this demonstration is data engineers who want  to understand the art of feaseable. 

[See the published documentation](https://jbcodeforce.github.io/healthcare-shift-left-demo)


