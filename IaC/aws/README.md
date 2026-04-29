# Tableflow: S3 and IAM (AWS only)

This root creates the S3 bucket and IAM role for Confluent Tableflow. Confluent UI steps and full documentation: [../README.md](../README.md) (section **Tableflow and S3**).

```sh
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform plan
terraform apply
```

State file: `terraform.tfstate` in this directory.
