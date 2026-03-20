# Quick Start for the demonstration


For developers [see the specific instructions](./dev_instructions.md) for running locally, with code structure and implementation approach descriptions.


## Prerequisites

* Get docker cli and docker compose, with access to public docker hub. The images are:
    * [jbcodeforce/healthcare-shift-left-demo-backend](https://hub.docker.com/repository/docker/jbcodeforce/healthcare-shift-left-demo-backend
    * [jbcodeforce/healthcare-shift-left-demo-frontend](https://hub.docker.com/repository/docker/jbcodeforce/healthcare-shift-left-demo-frontend)
    * [jbcodeforce/healthcare-shift-left-demo-kafka-connect](https://hub.docker.com/repository/docker/jbcodeforce/healthcare-shift-left-demo-kafka-connect)
* [Optional] get [terraform cli](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) (if you want to define infrastructure like Kafka Cluster, Flink Compute pool and deploy Flink statements)
* [Optional] get [shift_left utilities](https://jbcodeforce.github.io/shift_left_utils/) if you want to use a dbt like CLI to manage Flink project at scale

## Gather API Keys

At the minimum you need to get the API KEY and SECRETS for the user that will run the terraform, or the confluent CLI, or the shift_left CLI.

The backend uses one file for environment variables: the `./backend/.env`.

```sh
cp ./backend/.env.example ./backend/.env
```

Modify the top section of the file if you will create the environment, kafka cluster, schema registry and Flink Compute pool with Terraform.

```sh
CLOUD_PROVIDER="aws"
CLOUD_REGION="us-west-2"
ORG_ID="...."
CONFLUENT_CLOUD_API_KEY=....
CONFLUENT_CLOUD_API_SECRET=cflt....
```

## Infrastructure as Code

If you do not have a Confluent Cloud Environment, a Kafka cluster, schema registry and Flink compute pools, you can use the Terraform in the IaC folder. You can also reuse existing resources. We will explain that in a sub section

```sh
terraform init
terraform plan
terraform apply --auto-approve
```

The outputs should look like:

```sh
env_display_name = "health-env"
env_id = "env-r..."
flink_compute_pool_id = "lfcp-9....m"
flink_rest_endpoint = "https://flink.us-west-2.aws.confluent.cloud"
flink_statements_ddl_raw = {}
flink_statements_ddl_rmd = {}
flink_statements_dml_raw = {}
flink_statements_dml_rmd = {}
kafka_bootstrap_endpoint = "SASL_SSL://pkc-......us-west-2.aws.confluent.cloud:9092"
kafka_cluster_display_name = "health-kafka"
kafka_cluster_id = "lkc-...."
kafka_rest_endpoint = "https://pkc-.....us-west-2.aws.confluent.cloud:443"
schema_registry_endpoint = "https://psrc-......us-west-2.aws.confluent.cloud"
schema_registry_id = "lsrc-...."
```

### Reuse existing Confluent Cloud Resources

## Create CDC Topic

## Deploy the Flink Statements


## Local Execution Of the Demo Components

```sh
docker compose up -d
```

