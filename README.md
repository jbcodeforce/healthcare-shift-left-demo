# Healthcare Data Streaming Processing Demonstration


## Goals

The scope will be to build an end-to-end demonstration starting from Debezium CDC to flink SQL to process (Raw->Bronze->Silver->Gold records), with tableflow to s3 parquet/iceberg tables - finalized by using duckdb queries - Use healthcare use case, like Patient records, health provider , and device monitoring. Address Compliance to a prescription, i=or out of sequence events. We could use Flink to compare Command/Intent (The Prescription) against Reality (The Telemetry). audiance will be data engineers. demo user friendly platform to develop SQL streaming logic.  May be use HL7 FHIR.



## The Core Domain Classes

You typically need three main entities to show a meaningful "Patient Journey" in a stream: the Patient, the Provider, and the Encounter (the event linking them).

### A. Patient Class
This represents the static/slow-moving dimensions of the person.

```Java
public class Patient {
    public String patientId;   // Primary Key
    public String name;
    public String gender;
    public String birthDate;
    public String zipCode;     // Useful for Flink geo-aggregations
    
    // Default constructor for Flink/POJO serialization
    public Patient() {}
}
```

### B. HealthProvider Class
This represents the doctor or facility.

```Java
public class HealthProvider {
    public String providerId;
    public String organizationName;
    public String specialty;   // e.g., "Cardiology", "General Practice"
    public String NPI;         // National Provider Identifier
    
    public HealthProvider() {}
}
```

### C. Encounter (The Stream Event)
This is the "Fact" table that will flow through your Kafka topic. It is the most important class for Flink because it contains the timestamps.

```Java
public class Encounter {
    public String encounterId;
    public String patientId;    // Foreign Key to Patient
    public String providerId;   // Foreign Key to Provider
    public long timestamp;      // Event time for Flink Windowing
    public String type;         // e.g., "Inpatient", "Ambulatory", "Emergency"
    public double cost;         // For "Sum" or "Avg" aggregations
    public String diagnosisCode; // ICD-10 code
    
    public Encounter() {}
}
```

### D. Prescription Class

The "Desired State". It tells Flink what the device should be doing.

```Java
public class Prescription {
    public String prescriptionId;
    public String patientId;
    public String deviceId;
    public String medicationOrTherapy; // e.g., "CPAP Oxygen Flow"
    public double targetValue;          // e.g., 2.5 (Liters per minute)
    public double toleranceRange;      // e.g., 0.5 (Acceptable +/-)
    public long startDate;
    public long endDate;
    
    public Prescription() {}
}
```

### E. DeviceTelemetry 
The "Observed State": This is the high-velocity stream coming from the hardware.

```Java
public class DeviceTelemetry {
    public String deviceId;
    public String patientId;
    public long timestamp;
    public String metricName;          // e.g., "FlowRate", "BatteryLevel", "Pressure"
    public double metricValue;
    public String softwareVersion;     // Crucial for manufacturers (debugging)
    
    public DeviceTelemetry() {}
}
```

## The Flink Use Case

### Compliance Alerting

Use a join between the Prescription stream with the DeviceTelemetry stream to check for "Prescription Drift.
The prescriptions change rarely but apply to every telemetry point, we may want to use Broadcast State if done with DataStream. 
If DeviceTelemetry.metricValue is outside the Prescription.targetValue +/- toleranceRange for more than $X$ minutes, trigger an alert.
The Sink: Send the alert to a new Kafka topic: alerts.compliance.non-adherence.

### Device's health
Goal assess device reliability:

* Windowed Aggregation: Calculate the average BatteryLevel or InternalTemperature over a 1-hour tumbling window.
* Pattern Recognition: If the InternalTemperature increases by $>10% over three consecutive windows while FlowRate remains constant, the device may have a clogged filter.


If we do an insulin pump, we can have Flink detecting a spike in BloodGlucose (Telemetry). Then checks the Prescription for the maximum allowable dose, to finally sends a command back to a Kafka topic `device.commands` to trigger an insulin bolus automatically.