# Flink SQL statements

Deploys `confluent_flink_statement` resources from `../../pipelines/inventory.json` in four phases (raw/rmd DDL then DML).

**Prerequisite:** apply [../](../) (Confluent core) first so `../terraform.tfstate` contains pool, service account, and Flink API key outputs, **or** set `use_confluent_remote_state = false` and pass all values in `terraform.tfvars`.

```sh
cp terraform.tfvars.example terraform.tfvars
# set confluent_cloud_api_key / confluent_cloud_api_secret
terraform init
terraform plan
terraform apply
```

State file: `terraform.tfstate` in this directory. See [../README.md](../README.md) for the full three-stack flow.
