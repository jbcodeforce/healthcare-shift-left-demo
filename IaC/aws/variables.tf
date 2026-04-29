variable "cloud_region" {
  description = "AWS region for the S3 bucket and IAM role (e.g. us-west-2)"
  type        = string
  default     = "us-west-2"
}

variable "prefix" {
  description = "Prefix for S3 bucket and IAM resource names"
  type        = string
  default     = "health"
}

variable "enable_tableflow" {
  description = "When true, create S3 bucket and IAM role for Tableflow"
  type        = bool
  default     = false
}

variable "confluent_environment_id" {
  description = "Optional Confluent environment id (e.g. env-xxx) for S3 object tags; not used by AWS APIs"
  type        = string
  default     = ""
}

variable "confluent_aws_account_id" {
  description = "Confluent AWS account ID for the Tableflow assume-role trust"
  type        = string
  default     = "761327592718"
}

variable "confluent_external_id" {
  description = "External ID for Confluent Tableflow IAM role assumption (from Confluent UI or support)"
  type        = string
  default     = ""
  sensitive   = true
}
