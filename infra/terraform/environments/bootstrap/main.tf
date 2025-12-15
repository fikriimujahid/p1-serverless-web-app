terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.aws_region
  profile = "terraform-admin"
}

# GitHub OIDC Provider for CI/CD
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]

  tags = {
    project    = var.project
    managed_by = "terraform"
  }
}

# Create IAM roles using bootstrap admin credentials
module "iam_roles" {
  source = "../../modules/iam-roles"

  project                    = var.project
  terraform_state_bucket_arn = "arn:aws:s3:::${var.terraform_state_bucket}"
  github_oidc_provider_arn   = aws_iam_openid_connect_provider.github.arn
  github_repo                = var.github_repo
}

# Output role ARNs for reference
output "terraform_dev_role_arn" {
  value = module.iam_roles.terraform_dev_role_arn
}

output "terraform_prod_role_arn" {
  value = module.iam_roles.terraform_prod_role_arn
}

output "cicd_runner_role_arn" {
  value = module.iam_roles.cicd_runner_role_arn
}

output "github_oidc_provider_arn" {
  value = aws_iam_openid_connect_provider.github.arn
}