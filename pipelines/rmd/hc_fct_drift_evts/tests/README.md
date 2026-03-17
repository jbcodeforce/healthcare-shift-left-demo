# Unit tests explanations

The `hc_fct_drift_evts` uses 2 input tables as sources and generates record with the ['No primary key found in the statement.'] primary keys

## DML analysis


The joins are unbounded leading the Flink state growth.

These JOINs will accumulate unlimited state:
```sql

```


## Real data analysis

Running source data analysis, from the env-yk3jm6 environment:

| Table Name | # messages in topic | Information of interest |
|------------|------------|--------------|
| hc_device_metrics |  |  |
| hc_src_prescriptions |  |  |


## Unit tests creation and execution:

DDL -> 

| UT |   Inserts | Validation |
| --- | --- | --- |
| sql | ✅ | ✅  |

### Issues to address



### hc_device_metrics

* Example of record in topic:

```json
# add an example here as json object from the kafka topic
```

Analyze **data skew** with

```sql
select id, tenant_id, count(*) as record_count from hc_device_metrics  group by id, tenant_id
```


### hc_src_prescriptions

* Example of record in topic:

```json
# add an example here as json object from the kafka topic
```

Analyze **data skew** with

```sql
select id, tenant_id, count(*) as record_count from hc_src_prescriptions  group by id, tenant_id
```

