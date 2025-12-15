terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Configure in backend.hcl
  }
}

provider "aws" {
  region = var.aws_region

  assume_role {
    role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/TerraformProdRole"
  }
}

data "aws_caller_identity" "current" {}

# CRITICAL: Production protection - Block non-CI execution
locals {
  expected_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/TerraformProdRole"
}

resource "null_resource" "block_non_ci" {
  count = data.aws_caller_identity.current.arn == local.expected_role_arn ? 0 : 1

  provisioner "local-exec" {
    command = "echo '🚨 PROD APPLY BLOCKED — CI/CD ONLY' && exit 1"
  }
}

# Example resource with mandatory tags
resource "aws_s3_bucket" "example" {
  bucket = "${var.project}-${var.environment}-example-bucket"

  tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }

  depends_on = [null_resource.block_non_ci]
}