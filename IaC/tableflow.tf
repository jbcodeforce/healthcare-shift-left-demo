# Tableflow and S3 configuration for fact tables
# NOTE: Tableflow connections must be created via Confluent UI
# This file creates S3 bucket and IAM role only

# AWS Provider for S3 and IAM resources
# (AWS provider is declared in main.tf required_providers)
provider "aws" {
  region = var.cloud_region
}

# ------------------------------------------------------
# S3 Bucket for Analytics Data
# ------------------------------------------------------

resource "aws_s3_bucket" "analytics" {
  count  = var.enable_tableflow ? 1 : 0
  bucket = "${var.prefix}-healthcare-analytics-${random_id.bucket_suffix[0].hex}"

  tags = {
    Name        = "Healthcare Analytics Data"
    Environment = local.environment_id
    ManagedBy   = "Terraform"
    Project     = "healthcare-shift-left-demo"
  }
}

resource "random_id" "bucket_suffix" {
  count       = var.enable_tableflow ? 1 : 0
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "analytics" {
  count  = var.enable_tableflow ? 1 : 0
  bucket = aws_s3_bucket.analytics[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "analytics" {
  count  = var.enable_tableflow ? 1 : 0
  bucket = aws_s3_bucket.analytics[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Lifecycle policy to manage old data
resource "aws_s3_bucket_lifecycle_configuration" "analytics" {
  count  = var.enable_tableflow ? 1 : 0
  bucket = aws_s3_bucket.analytics[0].id

  rule {
    id     = "expire-old-data"
    status = "Enabled"

    filter {}  # Apply to all objects

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ------------------------------------------------------
# IAM Role and Policy for Confluent Tableflow
# ------------------------------------------------------

# IAM role that Confluent Tableflow will assume
resource "aws_iam_role" "tableflow" {
  count = var.enable_tableflow ? 1 : 0
  name  = "${var.prefix}-tableflow-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${var.confluent_aws_account_id}:root"
        }
        Action = "sts:AssumeRole"
        Condition = var.confluent_external_id != "" ? {
          StringEquals = {
            "sts:ExternalId" = var.confluent_external_id
          }
        } : null
      }
    ]
  })

  tags = {
    Name      = "Confluent Tableflow Role"
    ManagedBy = "Terraform"
    Project   = "healthcare-shift-left-demo"
  }
}

# IAM policy for S3 access
resource "aws_iam_policy" "tableflow_s3" {
  count       = var.enable_tableflow ? 1 : 0
  name        = "${var.prefix}-tableflow-s3-policy"
  description = "Allow Confluent Tableflow to write to S3 analytics bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.analytics[0].arn,
          "${aws_s3_bucket.analytics[0].arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListAllMyBuckets"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "tableflow_s3" {
  count      = var.enable_tableflow ? 1 : 0
  role       = aws_iam_role.tableflow[0].name
  policy_arn = aws_iam_policy.tableflow_s3[0].arn
}
