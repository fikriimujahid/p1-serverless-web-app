terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    # Configuration loaded from backend.hcl
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "terraform-dev"

  default_tags {
    tags = {
      project     = var.project
      environment = var.environment
      managed_by  = "terraform"
    }
  }
}

# Add your development infrastructure resources here
# Example resource with mandatory tags
resource "aws_s3_bucket" "example" {
  bucket = "${var.project}-${var.environment}-example-bucket"
}