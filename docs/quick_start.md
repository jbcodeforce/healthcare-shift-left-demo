# Quick Start for the demonstration


For developers [see the specific instructions](./dev_instructions.md) for running locally, with code structure and implementation approach descriptions.


### Prerequisites

* get docker and docker compose, with access to public docker hub. The images are [jbcodeforce](https://hub.docker.com/repositories/jbcodeforce)
* [Optional] get terraform (if you want to define infrastructure and deploy Flink statrment using it)
* [Optional] get [shift_left utilities](https://jbcodeforce.github.io/shift_left_utils/) if you want to use a dbt like CLI to manage Flink project at scale

### Infrastructure as Code

If you do not have a Confluent Cloud Environment, a Kafka cluster and fink compute pools, you can use the Terraform in the IaC folder.

### Local Execution

```sh
docker compose up -d
```
