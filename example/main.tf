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

resource "random_id" "id" {
  keepers = {
    email_id = var.email_id
  }

  byte_length = 2
}

resource "aws_organizations_organization" "test_org" {
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
  ]

  feature_set = "ALL"
}

resource "aws_organizations_organizational_unit" "accounts" {
  name      = "accounts"
  parent_id = aws_organizations_organization.test_org.roots[0].id
}

resource "aws_organizations_organizational_unit" "shared_devices" {
  name      = "shared_devices"
  parent_id = aws_organizations_organizational_unit.accounts.id
}

resource "aws_organizations_organizational_unit" "workloads" {
  name      = "workloads"
  parent_id = aws_organizations_organizational_unit.accounts.id
}

resource "aws_organizations_account" "cloudops_dev" {
  name      = "CloudOps DemoEnv Dev Account"
  email     = "${var.account_name}+${random_id.id.keepers.email_id}@${var.email_domain}"
  parent_id = aws_organizations_organizational_unit.workloads.id

  close_on_deletion = true
}

resource "aws_organizations_account" "cloudops_qa" {
  name      = "CloudOps DemoEnv QA Account"
  email     = "${var.account_name}+${random_id.id.keepers.email_id}@${var.email_domain}"
  parent_id = aws_organizations_organizational_unit.workloads.id

  close_on_deletion = true
}

resource "aws_organizations_account" "cloudops_delegated_admin" {
  name      = "CloudOps DemoEnv Delegated Admin Account"
  email     = "${var.account_name}+${random_id.id.keepers.email_id}@${var.email_domain}"
  parent_id = aws_organizations_organizational_unit.shared_devices.id

  close_on_deletion = true
}

resource "aws_organizations_delegated_administrator" "" {
  account_id = aws_organizations_account.cloudops_delegated_admin.id
}
