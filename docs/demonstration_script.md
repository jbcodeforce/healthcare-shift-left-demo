# Demonstration Scenarios

Once the WebApplication is started, all the demonstration happens in this application and within Confluent Cloud console.

## 1- Review the Domain

1. We have fake patients (few of them as the volume is not the scope of the demonstration)
    ![](./images/patients_view.png)

1. We have a set of devices assigned to patient with 3 major parameters. Those parameters will be used during the simulation to detect anomaly, and work with real-time telemetries.
    ![](./images/devices_view.png)

1. Doctors have set prescriptions to patient that will specify device configuration. A prescription is simply modeled as defining the setting for the different parameters.
    ![](./images/prescriptions_view.png)

## 2- Review the pipeline processing

The pipeline structure looks like:
![]()

### Bronze layer


### 2.1 Envelop processing

Debezium CDC connectors automatically register the message schema when writing to Kafka topics. Using Debezium CDC, the schema structure will include before, after, timestamp, op and sources fields:

![](./images/patient_envelop.png)

In Confluent Flink there are two options to manage those envelops:
1. Use the `avro-debezium-registry` serialization: [to automatically detect and interpret this envelope structure based on the schema in Confluent Schema Registry.](https://docs.confluent.io/cloud/current/flink/reference/serialization.html#debezium-format). The `healthcare.public.prescriptions` has the `value.format` set to 'avro-debezium-registry' automatically. Its changelog mode is also set to Retract
    ```sql
    show create table `healthcare.public.prescriptions`
    ```

    A select from returns the expected record content:
    
    ![](./images/hc_cdc_prescriptions.png)

    Retract mode is not compatible with the after.state.only option of Debezium connectors.
1. Use the envelop to keep changelog mode ot append only, and the delete operation need to be propagated to the downstream processing.
    ```sql
    INSERT INTO hc_src_patients
    WITH normalized AS (
    SELECT
        coalesce(if(op = 'd', before.patient_id, after.patient_id), 'dummy_patient_id') AS patient_id,
        coalesce(if(op = 'd', before.name, after.name), 'dummy_name') AS name,
        coalesce(if(op = 'd', before.gender, after.gender), 'dummy_gender') AS gender,
        coalesce(if(op = 'd', before.birth_date, after.birth_date), 'dummy_birth_date') AS birth_date,
        coalesce(if(op = 'd', before.zip_code, after.zip_code), 'dummy_zip_code') AS zip_code,
        source_ts_ms,
        op
    FROM hc_raw_patients
    ),
    deduped AS (
    SELECT
        patient_id,
        name,
        gender,
        birth_date,
        zip_code,
        source_ts_ms,
        op,
        ROW_NUMBER() OVER (PARTITION BY patient_id ORDER BY source_ts_ms DESC) AS rn
    FROM normalized
    )

    SELECT patient_id, name, gender, birth_date, zip_code, source_ts_ms, op
    FROM deduped
    WHERE rn = 1
    ```

### 2.2 Deduplication

* Upsert changelog.mode will remove any duplicate per key. No need to do the row_number() pattern
* Still it may be relevant to use this pattern some time to time, specially if some deduplication needs to be done on specific field out side of the primary key of the sink table.

### 2.3 Analyze CDC processing

1. Verify current state of the Patients Dimension
    ```sql
    select * from hc_dim_patients
    ```

    ![](./images/dim_patients.png)

1. Create a new prescription from the User interface: Be sure to select the good device for the patient. (this will be a user interface improvement to be done)
    ![](./images/new_prescription.png)


    If you use a SQL query on top of the Postgresql Database, we can see a new row was added:
    ![](./images/pg_presc_table.png)

    We can verify in Confluent Cloud the topic has the new record:
    ```sql
    select * from `healthcare.public.prescriptions`
    ```

    ![](./images/cdc_topic_content.png)



## 3- The first data analytic product

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