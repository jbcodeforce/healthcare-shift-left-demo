# Confluent Cloud Terraform (Environment, Kafka, Flink)

This folder contains Terraform definitions for the healthcare-shift-left-demo Confluent Cloud setup: **environment**, **Kafka cluster**, and **Flink compute pool**. You can either create all resources or attach to an existing environment and/or Kafka cluster using variables.

## Resources

| Resource            | When created                          |
|---------------------|----------------------------------------|
| Confluent Environment | When `environment_id` is not set     |
| Kafka Cluster       | When `kafka_cluster_id` is not set    |
| Flink Compute Pool  | Always (in the target environment)   |

## File structure

```
├── main.tf                    # Provider and data sources
├── variables.tf               # Variable definitions
├── terraform.tfvars.example  # Example variable values
├── env.tf                     # Environment (create or use existing)
├── kafka.tf                   # Kafka cluster (create or use existing)
├── flink.tf                   # Flink compute pool
├── outputs.tf                 # Output values
└── README.md                  # This file
```

## Prerequisites

1. **Confluent Cloud account** with API access.
2. **API key and secret** with permissions to create environments, clusters, and Flink compute pools (e.g. OrganizationAdmin, or EnvironmentAdmin + CloudClusterAdmin for the create path).
3. Set credentials (do not commit `terraform.tfvars`):

   ```sh
   export TF_VAR_confluent_cloud_api_key="<your-api-key>"
   export TF_VAR_confluent_cloud_api_secret="<your-api-secret>"
   ```

   Or copy `terraform.tfvars.example` to `terraform.tfvars` and set `confluent_cloud_api_key` and `confluent_cloud_api_secret` there.

## Create (provision all or attach to existing)

From this directory:

```sh
terraform init
terraform plan
terraform apply
```

- **Default (no variables set):** Creates a new environment, Kafka cluster (standard, single zone), and a Flink compute pool.
- **Use existing environment:** Set `environment_id = "env-xxxxx"` in `terraform.tfvars` or via `-var`. Terraform will create only the Kafka cluster (if not existing) and the Flink compute pool in that environment.
- **Use existing environment and Kafka:** Set both `environment_id` and `kafka_cluster_id`. Terraform will create only the Flink compute pool. **When using `kafka_cluster_id`, `environment_id` must also be set** (the cluster belongs to that environment).

Example with existing resources:

```sh
terraform apply -var='environment_id=env-xxxxx' -var='kafka_cluster_id=lkc-xxxxx'
```

## Clean (destroy managed resources)

```sh
terraform destroy
```

- If you **created** the environment and Kafka cluster with this Terraform, they will be destroyed along with the Flink compute pool.
- If you **used existing** environment and/or Kafka cluster (via variables), only the Flink compute pool (and any other resources this configuration created) are destroyed; the existing environment and cluster are not modified.

## Outputs

After apply:

```sh
terraform output
```

Useful outputs: `env_id`, `kafka_cluster_id`, `kafka_bootstrap_endpoint`, `kafka_rest_endpoint`, `flink_compute_pool_id`, `flink_rest_endpoint`.

## Variables summary

| Variable                      | Required | Description |
|------------------------------|----------|-------------|
| `confluent_cloud_api_key`    | Yes      | Confluent Cloud API key |
| `confluent_cloud_api_secret` | Yes      | Confluent Cloud API secret |
| `environment_id`             | No       | Existing environment ID; when set, no environment is created |
| `kafka_cluster_id`           | No       | Existing Kafka cluster ID; when set, no cluster is created (requires `environment_id`) |
| `cloud_provider`             | No       | e.g. `AWS` (default) |
| `cloud_region`               | No       | e.g. `us-east-1` (default) |
| `prefix`                     | No       | Prefix for created resource names (default `healthcare-demo`) |
| `flink_compute_pool_name`    | No       | Flink pool display name (default `healthcare-demo-pool`) |
| `flink_compute_pool_max_cfu` | No       | Max CFU for the pool (default `5`) |
