# Demonstration Scenarios

## 1- Review the Domain

1. We have patients
    ![](./images/patients_view.png)

1. We have a set of devices in the field
    ![](./images/devices_view.png)

1. Doctors have set prescriptions that will specify device configuration
    ![](./images/prescriptions_view.png)

## 2- The first data analytic product

This is counting the number of time a device configuration was changed per patient. We can go step by step to deploy each flink statements, or via one deployment taking care of the full pipeline deployment.

### Step-by-step using Confluent Console - Workspace View

#### Process raw tables
The Patients and Devices are for demonstration purpose created with Flink and with prepopulated records. In the console workspace you can copy paste the SQLs in the following order:

* DDL hc_raw_devices from [../pipelines/raw/raw_devices/sql-scripts/ddl.raw_devices.sql](../pipelines/raw/raw_devices/sql-scripts/ddl.raw_devices.sql)
* Insert some records to the hc_raw_devices topic  [../pipelines/raw/raw_devices/sql-scripts/dml.raw_devices.sql](../pipelines/raw/raw_devices/sql-scripts/dml.raw_devices.sql)
* Create patients [../pipelines/raw/raw_patients/sql-scripts/ddl.raw_patients.sql](../pipelines/raw/raw_devices/sql-scripts/ddl.raw_patients.sq)
* Insert patient records [../pipelines/raw/raw_patients/sql-scripts/dml.raw_patients.sql](../pipelines/raw/raw_devices/sql-scripts/dml.raw_patients.sq)

This should be the current state:
![](./images/patients_devices_data.png)

### 