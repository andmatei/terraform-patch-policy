terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# TODO: Declare providers for all specified regions
provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

# TODO: Define the IAM

# Automation Administration role

resource "aws_iam_role" "ssm_maintenance_window" {
  name = "ssm-mw-role"
  path = "/"

  assume_role_policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Action = "sts:AssumeRole",
          Principal = {
            Service = ["ec2.amazonaws.com", "ssm.amazonaws.com"]
          },
          Effect = "Allow",
        }
      ]
    }
  )
}

resource "aws_iam_policy" "admin" {
  name = "AssumeRole-AWSSystemsManagerAutomationExecutionRole"
  policy = jsonencode(
    {
      Version = "2012-10-17",
      Statement = [
        {
          Effect   = "Allow",
          Action   = ["organizations:ListAccountsForParent"]
          Resource = "*"
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "ssm_maintenance_window" {
  role       = aws_iam_role.ssm_maintenance_window.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonSSMMaintenanceWindowRole"
}

# TODO: Define a custom patch baseline
data "aws_ssm_patch_baseline" "name" {
  owner            = "AWS"
  name_prefix      = "AWS-"
  operating_system = "WINDOWS"
  default_baseline = true
}

resource "aws_ssm_patch_group" "patchgroup" {
  baseline_id = data.aws_ssm_patch_baseline.id
  patch_group = "windows-patch-group"
}

resource "aws_ssm_maintenance_window" "scan" {
  name        = "scan-"
  description = "Maintenance window for scanning for patch compliance"
  schedule    = var.scan_schedule
  duration    = var.scan_duration
  cutoff      = var.scan_cutoff
}

resource "aws_ssm_maintenance_window" "install" {
  count = var.install_patches ? 1 : 0

  name        = "install-"
  description = "Maintenance window for applying patches"
  schedule    = var.install_schedule
  duration    = var.install_duration
  cutoff      = var.install_cutoff
}

resource "aws_ssm_maintenance_window_target" "scan" {
  window_id     = aws_ssm_maintenance_window.scan.id
  resource_type = "INSTANCE"

  targets {
    key    = var.instance_tag ? "tag:${var.instance_tag}" : "InstanceIds"
    values = var.instance_tag ? [var.instance_tag] : ["*"]
  }
}

resource "aws_ssm_maintenance_window_target" "install" {
  count         = var.install_patches ? 1 : 0
  window_id     = aws_ssm_maintenance_window.install.id
  resource_type = "INSTANCE"

  targets {
    key    = var.instance_tag ? "tag:${var.instance_tag}" : "InstanceIds"
    values = var.instance_tag ? [var.instance_tag] : ["*"]
  }
}

resource "aws_ssm_maintenance_window_task" "scan" {
  priority  = 1
  task_arn  = "AWS-RunPatchBaseline"
  task_type = "RUN_COMMAND"
  window_id = aws_ssm_maintenance_window.scan.id

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.scan.id]
  }

  # TODO: Add notifications and S3 output
  task_invocation_parameters {
    run_command_parameters {
      comment = "Run compliance scan"

      parameter {
        name   = "Operation"
        values = ["Scan"]
      }
    }
  }
}

resource "aws_ssm_maintenance_window_task" "install" {
  priority  = 1
  task_type = "RUN_COMMAND"
  task_arn  = "AWS-RunPatchBaseline"
  window_id = aws_ssm_maintenance_window.install.id

  targets {
    key    = "WindowTargetIds"
    values = [aws_ssm_maintenance_window_target.install.id]
  }

  task_invocation_parameters {
    run_command_parameters {
      comment = "Install patches"

      parameter {
        name   = "Operation"
        values = ["Install"]
      }
    }
  }
}
