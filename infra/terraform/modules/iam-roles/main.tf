data "aws_caller_identity" "current" {}

locals {
  allowed_subs = [
    "repo:${var.github_repo}:ref:refs/heads/dev",
    "repo:${var.github_repo}:ref:refs/heads/staging",
    "repo:${var.github_repo}:ref:refs/heads/main",
    "repo:${var.github_repo}:pull_request",
    "repo:${var.github_repo}:environment:dev",
    "repo:${var.github_repo}:environment:staging",
    "repo:${var.github_repo}:environment:prod"
  ]
}

# TerraformDevRole - For local dev/staging Terraform
resource "aws_iam_role" "terraform_dev" {
  name = "TerraformDevRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/terraform-admin"
        }
        Condition = {
          StringEquals = {
            "sts:ExternalId" = "terraform-dev"
          }
        }
      },
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.github_oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = local.allowed_subs
          }
        }
      }
    ]
  })

  tags = {
    project     = var.project
    environment = "shared"
    managed_by  = "terraform"
  }
}

# TerraformProdRole - CI/CD ONLY
resource "aws_iam_role" "terraform_prod" {
  name = "TerraformProdRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.github_oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = local.allowed_subs
          }
        }
      }
    ]
  })

  tags = {
    project     = var.project
    environment = "shared"
    managed_by  = "terraform"
  }
}

# CICDRunnerRole - For GitHub Actions CI/CD
resource "aws_iam_role" "cicd_runner" {
  name = "CICDRunnerRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Federated = var.github_oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            "token.actions.githubusercontent.com:sub" = local.allowed_subs
          }
        }
      }
    ]
  })

  tags = {
    project     = var.project
    environment = "shared"
    managed_by  = "terraform"
  }
}

# Policy for TerraformDevRole - Full access except prod resources
resource "aws_iam_policy" "terraform_dev_policy" {
  name = "TerraformDevPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = "*"
      },
      {
        Effect = "Deny"
        Action = "*"
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:ResourceTag/environment" = "prod"
          }
        }
      },
      {
        Effect = "Deny"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = "${var.terraform_state_bucket_arn}/prod/*"
      }
    ]
  })

  tags = {
    project     = var.project
    environment = "shared"
    managed_by  = "terraform"
  }
}

# Policy for TerraformProdRole - Full access to prod only
resource "aws_iam_policy" "terraform_prod_policy" {
  name = "TerraformProdPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "*"
        Resource = "*"
      }
    ]
  })

  tags = {
    project     = var.project
    environment = "shared"
    managed_by  = "terraform"
  }
}

# Policy for CICDRunnerRole
resource "aws_iam_policy" "cicd_runner_policy" {
  name = "CICDRunnerPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = [
          aws_iam_role.terraform_dev.arn,
          aws_iam_role.terraform_prod.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })

  tags = {
    project     = var.project
    environment = "shared"
    managed_by  = "terraform"
  }
}

# Attach policies to roles
resource "aws_iam_role_policy_attachment" "terraform_dev_attach" {
  role       = aws_iam_role.terraform_dev.name
  policy_arn = aws_iam_policy.terraform_dev_policy.arn
}

resource "aws_iam_role_policy_attachment" "terraform_prod_attach" {
  role       = aws_iam_role.terraform_prod.name
  policy_arn = aws_iam_policy.terraform_prod_policy.arn
}

resource "aws_iam_role_policy_attachment" "cicd_runner_attach" {
  role       = aws_iam_role.cicd_runner.name
  policy_arn = aws_iam_policy.cicd_runner_policy.arn
}