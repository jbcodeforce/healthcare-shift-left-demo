# Healthcare Data Streaming Processing Demonstration

Created 03/10/2026 - Updated 03/15/26

## Goals

The scope of this repository is to build an end-to-end healthcare related demonstration, starting from Debezium CDC to Confluent Cloud Kafka, Flink SQL to process Raw->Bronze->Silver->Gold records, to sink s3 parquet/iceberg tables.

The approach is to use healthcare use case, like Patient records, health provider, prescriptions and device monitoring. The demonstration illustrates device monitoring and compliance to a doctor's prescription. With the basic domain model but representing good foundations to present different real-time processing use cases. We use Flink to compare Command/Intent (The Prescription) against Reality (The Telemetry). 

The audiance of this demonstration is data engineers to understand the art of feaseable. 

[See the publish documentation](https://jbcodeforce.github.io/healthcare-shift-left-demo)
