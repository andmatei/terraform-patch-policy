terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

data "aws_region" "this" {}

data "aws_caller_identity" "this" {}

# Key used to encrypt instance data
# TODO: To be finished

# resource "aws_kms_key" "this" {
#   description         = "Key used to encrypt instance data"
#   enable_key_rotation = true
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Action = [
#           "cloudhsm:InitializeCluster",
#           "cloudhsm:DescribeClusters",
#         ],
#         Resource = "*"
#       }
#     ]
#   })
# }

# S3 - Instance Data

resource "aws_s3_bucket" "resource_sync" {
  bucket = "ssm-resource-sync-${data.aws_region.this.name}-${data.aws_caller_identity.this.account_id}"
}

resource "aws_s3_bucket_versioning" "resource_sync" {
  bucket = aws_s3_bucket.resource_sync.id
  versioning_configuration {
    status = "Enabled"
  }
}

# resource "aws_s3_bucket_server_side_encryption_configuration" "resource_sync" {
#   bucket = aws_s3_bucket.resource_sync.id
#   rule {
#     apply_server_side_encryption_by_default {
#       #   kms_master_key_id = aws_kms_key.this.id
#       sse_algorithm = "aws:kms"
#     }
#   }
# }

resource "aws_s3_bucket_public_access_block" "resource_sync" {
  bucket                  = aws_s3_bucket.resource_sync.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Data Sync
resource "aws_ssm_resource_data_sync" "resource_sync" {
  name = "inventory-ssm"
  s3_destination {
    bucket_name = aws_s3_bucket.resource_sync.bucket
    prefix      = local.resource_data_sync_prefix
    region      = data.aws_region.this
    # kms_key_arn = aws_kms_key.this.arn
  }
}

# Glue
resource "aws_glue_catalog_database" "this" {
  name        = "ssm-global-resource-sync"
  description = "Systems Manager Global Resource Data Sync Database"
}

resource "aws_glue_crawler" "this" {
  database_name = aws_glue_catalog_database.this.name
  description   = "Crawler for AWS Systems Manager Resource Data Sync"
  name          = "ssm-glue-crawler"
  role          = aws_iam_role.glue_crawler_role.arn

  schema_change_policy {
    delete_behavior = "DELETE_FROM_DATABASE"
    update_behavior = "UPDATE_IN_DATABASE"
  }

  schedule = "cron(0 0 * * ? *)"

  s3_target {
    path       = "s3://${aws_s3_bucket.this.bucket}"
    exclusions = "${ResourceDataSyncPrefix}/AWS:InstanceInformation/accountid=*/test.json"
  }
}

resource "aws_iam_role" "glue_crawler_role" {
  name        = "ssm-glue-crawler-role"
  description = "Role created for Glue to access resource data sync S3 bucket"
  path        = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = ["glue.amazonaws.com"]
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "s3_actions" {
  name = "S3Actions"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.resource_sync.arn}/*"
      },
      {
        Effect = "Allow",
        Action = ["kms:Decrypt"]
        # Resorce = "${}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "glue_crawler_s3_actions" {
  role       = aws_iam_role.glue_crawler_role.name
  policy_arn = aws_iam_policy.s3_actions.arn
}

# S3 - Athena
resource "aws_s3_bucket" "athena" {
  bucket = "ssm-res-sync-athena-query-results-${data.aws_region.name}-${data.aws_caller_identity.account_id}"
}

# resource "aws_s3_bucket_server_side_encryption_configuration" "athena" {
#   bucket = aws_s3_bucket.athena.id
#   rule {
#     apply_server_side_encryption_by_default {
#       #   kms_master_key_id = aws_kms_key.this.id
#       sse_algorithm = "aws:kms"
#     }
#   }
# }

resource "aws_s3_bucket_public_access_block" "athena" {
  bucket                  = aws_s3_bucket.athena.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Athena

resource "aws_athena_workgroup" "this" {
  name          = "patch-policy-report-workgroup"
  state         = "ENABLED"
  force_destroy = true

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena.bucket}"
    }
  }
}

resource "aws_athena_named_query" "compliant" {
  description = "Query to list managed instances that are compliant for patching."
  name        = "QueryCompliantPatch"
  workgroup   = aws_athena_workgroup.this.id
}
