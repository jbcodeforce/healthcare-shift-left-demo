output "s3_analytics_bucket" {
  description = "S3 bucket name for analytics data"
  value       = var.enable_tableflow ? aws_s3_bucket.analytics[0].bucket : null
}

output "s3_analytics_bucket_arn" {
  description = "S3 bucket ARN for analytics data"
  value       = var.enable_tableflow ? aws_s3_bucket.analytics[0].arn : null
}

output "s3_analytics_bucket_region" {
  description = "S3 bucket region"
  value       = var.enable_tableflow ? aws_s3_bucket.analytics[0].region : null
}

output "tableflow_iam_role_arn" {
  description = "IAM role ARN for Confluent Tableflow"
  value       = var.enable_tableflow ? aws_iam_role.tableflow[0].arn : null
}

output "analytics_s3_paths" {
  description = "S3 paths for analytics data (Tableflow connections are created in the Confluent UI)"
  value = var.enable_tableflow ? {
    anomalies            = "s3://${aws_s3_bucket.analytics[0].bucket}/anomalies"
    prescription_changes = "s3://${aws_s3_bucket.analytics[0].bucket}/prescription_changes"
    telemetries          = "s3://${aws_s3_bucket.analytics[0].bucket}/telemetries"
  } : {}
}

output "tableflow_note" {
  description = "Tableflow setup instructions"
  value       = var.enable_tableflow ? "S3 and IAM are ready. Configure Tableflow connections and sinks in the Confluent Cloud UI. See ../README.md (Tableflow and S3)." : "Tableflow AWS resources not enabled. Set enable_tableflow=true in terraform.tfvars"
}
