# Tracking 

## User Stories

### Building golden records

| Artifact | status |
| ---- | ---- |
| code | |
| flink | | 
| IaC | | 
| Doc in demo script | |
| Doc in dev instruction | | 
| Support in UI | | 

### Compliance Alerting

| Artifact | status |
| ---- | ---- |
| code | |
| flink | | 
| IaC | | 
| Doc in demo script | |
| Doc in dev instruction | | 
| Support in UI | | 

### Device's health

| Artifact | status |
| ---- | ---- |
| code | |
| flink | | 
| IaC | | 
| Doc in demo script | |
| Doc in dev instruction | | 
| Support in UI | | 

### First Button Press

| Artifact | status |
| ---- | ---- |
| code | |
| flink | | 
| IaC | | 
| Doc in demo script | |
| Doc in dev instruction | | 
| Support in UI | | 

### Geofence Crossing

| Artifact | status |
| ---- | ---- |
| code | |
| flink | | 
| IaC | | 
| Doc in demo script | |
| Doc in dev instruction | | 
| Support in UI | | 

###  Device management

| Artifact | status |
| ---- | ---- |
| code | |
| flink | | 
| IaC | | 
| Doc in demo script | |
| Doc in dev instruction | | 
| Support in UI | | 

## Documentation

| doc | status |
| ---- | ---- |
| main index.md | |
| demonstration_script.md | | 
| quick_start.md | | 
| dev_instruction.md | |
| first readme | | 


## Backend testing Coverage

## Infrastructure as code

## Flink statement deployment

### Using shift_left utils

1. Set environment variables: ` eval "$(set_shift_left_env.py)"` and `source set_sl_env` to local PIPELINES and SL_CONFIG_FILE
1. Update inventory: `shift_left table build-inventory`
1. Update table metadata: `shift_left  pipeline build-all-metadata`
1. Deploy raws tables: `shift_left pipeline deploy --product-name raw`