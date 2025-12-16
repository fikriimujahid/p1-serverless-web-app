# 🏗️ Infrastructure Implementation Guide
**Phase 2 Implementation · Post-Terraform Setup · Production-Ready**

## 🎯 Objective

Implement the complete serverless infrastructure foundation using Terraform modules, following the architecture defined in [02-infra.md](./02-infra.md) and IAM security model from [02-iam.md](./02-iam.md).

**Prerequisites:** Complete [02-terraform-setup.md](../guide/02-terraform-setup.md) first.

---

## 📋 Implementation Checklist

- [ ] Terraform backend configured and tested
- [ ] IAM roles created and validated
- [ ] All infrastructure modules implemented
- [ ] Environment-specific configurations created
- [ ] Security policies enforced
- [ ] Infrastructure deployed and tested

---

# PHASE 1: Infrastructure Modules Implementation

## Step 1: Create Terraform Module Structure

```bash
# Navigate to project root
cd c:\DEMOP\p1-serverless-web-app

# Create module directories
mkdir infra\terraform\modules\iam
mkdir infra\terraform\modules\database
mkdir infra\terraform\modules\compute
mkdir infra\terraform\modules\auth
mkdir infra\terraform\modules\security
mkdir infra\terraform\modules\hosting
```
## Step 2: Implement IAM Module

### Create `infra/terraform/modules/iam/main.tf`

```hcl
# Lambda Execution Role
resource "aws_iam_role" "lambda_execution_role" {
  name = "${var.project}-lambda-execution-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Lambda Execution Policy
resource "aws_iam_role_policy" "lambda_execution_policy" {
  name = "${var.project}-lambda-execution-policy-${var.environment}"
  role = aws_iam_role.lambda_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.project}-*-${var.environment}"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:${var.project}/*"
      }
    ]
  })
}

# Cognito Service Role
resource "aws_iam_role" "cognito_service_role" {
  name = "${var.project}-cognito-service-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "cognito-idp.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}
```

### Create `infra/terraform/modules/iam/variables.tf`

```hcl
variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
```

### Create `infra/terraform/modules/iam/outputs.tf`

```hcl
output "lambda_execution_role_arn" {
  description = "ARN of Lambda execution role"
  value       = aws_iam_role.lambda_execution_role.arn
}

output "cognito_service_role_arn" {
  description = "ARN of Cognito service role"
  value       = aws_iam_role.cognito_service_role.arn
}
```
## Step 3: Implement Database Module
### Create `infra/terraform/modules/database/main.tf`
```hcl
# Notes DynamoDB Table
resource "aws_dynamodb_table" "notes_table" {
  name           = "${var.project}-notes-${var.environment}"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "userId"
  range_key      = "noteId"

  attribute {
    name = "userId"
    type = "S"
  }

  attribute {
    name = "noteId"
    type = "S"
  }

  attribute {
    name = "createdAt"
    type = "S"
  }

  global_secondary_index {
    name     = "UserCreatedAtIndex"
    hash_key = "userId"
    range_key = "createdAt"
  }

  point_in_time_recovery {
    enabled = var.environment == "prod"
  }

  server_side_encryption {
    enabled = true
  }

  tags = merge(var.tags, {
    Name = "${var.project}-notes-${var.environment}"
  })
}
```
### Create `infra/terraform/modules/database/variables.tf`
```hcl
variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
```
### Create `infra/terraform/modules/database/outputs.tf`
```hcl
output "notes_table_name" {
  description = "Name of the notes DynamoDB table"
  value       = aws_dynamodb_table.notes_table.name
}

output "notes_table_arn" {
  description = "ARN of the notes DynamoDB table"
  value       = aws_dynamodb_table.notes_table.arn
}
```
## Step 4: Implement Auth Module
### Create `infra/terraform/modules/auth/main.tf`
```hcl
# Cognito User Pool
resource "aws_cognito_user_pool" "notes_user_pool" {
  name = "${var.project}-auth-pool-${var.environment}"

  username_attributes = ["email"]
  
  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = true
    require_uppercase = true
  }

  verification_message_template {
    default_email_option = "CONFIRM_WITH_CODE"
    email_subject        = "Your verification code"
    email_message        = "Your verification code is {####}"
  }

  schema {
    attribute_data_type = "String"
    name               = "email"
    required           = true
    mutable            = true
  }

  tags = var.tags
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "notes_user_pool_client" {
  name         = "${var.project}-auth-client-${var.environment}"
  user_pool_id = aws_cognito_user_pool.notes_user_pool.id

  generate_secret = false
  
  explicit_auth_flows = [
    "ALLOW_USER_PASSWORD_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  supported_identity_providers = ["COGNITO"]
}
```
### Create `infra/terraform/modules/auth/variables.tf`
```hcl
variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
```
### Create `infra/terraform/modules/auth/outputs.tf`
```hcl
output "user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.notes_user_pool.id
}

output "user_pool_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.notes_user_pool_client.id
}

output "user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.notes_user_pool.arn
}
```
## Step 5: Implement Hosting Module
### Create `infra/terraform/modules/hosting/main.tf`
```hcl
# S3 Bucket for Frontend Hosting
resource "aws_s3_bucket" "frontend_bucket" {
  bucket = "${var.project}-frontend-${var.environment}-${random_string.bucket_suffix.result}"

  tags = var.tags
}

resource "random_string" "bucket_suffix" {
  length  = 8
  special = false
  upper   = false
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "frontend_bucket_pab" {
  bucket = aws_s3_bucket.frontend_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "frontend_bucket_versioning" {
  bucket = aws_s3_bucket.frontend_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Server Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend_bucket_encryption" {
  bucket = aws_s3_bucket.frontend_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                              = "${var.project}-frontend-oac-${var.environment}"
  description                       = "OAC for ${var.project} frontend ${var.environment}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "frontend_distribution" {
  origin {
    domain_name              = aws_s3_bucket.frontend_bucket.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
    origin_id                = "S3-${aws_s3_bucket.frontend_bucket.id}"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "S3-${aws_s3_bucket.frontend_bucket.id}"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = var.tags
}

# S3 Bucket Policy for CloudFront
resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  bucket = aws_s3_bucket.frontend_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.frontend_distribution.arn
          }
        }
      }
    ]
  })
}
```
### Create `infra/terraform/modules/hosting/variables.tf`
```hcl
variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}
```
### Create `infra/terraform/modules/hosting/outputs.tf`
```hcl
output "frontend_bucket_name" {
  description = "Name of the frontend S3 bucket"
  value       = aws_s3_bucket.frontend_bucket.id
}

output "cloudfront_distribution_id" {
  description = "ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.frontend_distribution.id
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = aws_cloudfront_distribution.frontend_distribution.domain_name
}
```

---
# PHASE 2: Environment Configuration
## Step 6: Create Environment-Specific Configurations
### Create `infra/terraform/environments/dev` using `terraform.tfvars`
For environment-specific configuration we recommend using `terraform.tfvars` (and a `terraform.tfvars.example` template) instead of embedding defaults in `variables.tf`. Keep `variables.tf` in the environment directory to *declare* variables (no defaults), then provide concrete values in `terraform.tfvars`.

Create `infra/terraform/environments/dev/main.tf` (backend loaded from `backend.hcl`):

```hcl
terraform {
  required_version = ">= 1.5"
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

locals {
  common_tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}

module "iam" {
  source = "../../modules/iam"

  project     = var.project
  environment = var.environment
  tags        = local.common_tags
}

module "database" {
  source = "../../modules/database"

  project     = var.project
  environment = var.environment
  tags        = local.common_tags
}

module "auth" {
  source = "../../modules/auth"

  project     = var.project
  environment = var.environment
  tags        = local.common_tags
}

module "hosting" {
  source = "../../modules/hosting"

  project     = var.project
  environment = var.environment
  tags        = local.common_tags
}
```

Create `infra/terraform/environments/dev/variables.tf` (no defaults here):

```hcl
variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}
```

Create a `terraform.tfvars.example` as your editable template, then copy it to `terraform.tfvars` and update values for your environment.
### Create `infra/terraform/environments/dev/terraform.tfvars.example`
```hcl
project                 = "notesapp"
environment             = "dev"
aws_region              = "us-east-1"
```

Then create the real file by copying the example and editing values locally:

```bash
cd infra/terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your environment-specific values
```

Create `infra/terraform/environments/dev/backend.hcl` (backend settings used by `terraform init -backend-config=backend.hcl`):

```hcl
bucket         = "notesapp-terraform-state-fikri"
key            = "dev/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "notesapp-terraform-locks"
encrypt        = true
profile        = "terraform-dev"
```

Create `infra/terraform/environments/dev/outputs.tf` to expose module outputs (same as before):

```hcl
output "lambda_execution_role_arn" {
  description = "ARN of Lambda execution role"
  value       = module.iam.lambda_execution_role_arn
}

output "notes_table_name" {
  description = "Name of the notes DynamoDB table"
  value       = module.database.notes_table_name
}

output "user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = module.auth.user_pool_id
}

output "user_pool_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = module.auth.user_pool_client_id
}

output "frontend_bucket_name" {
  description = "Name of the frontend S3 bucket"
  value       = module.hosting.frontend_bucket_name
}

output "cloudfront_domain_name" {
  description = "Domain name of the CloudFront distribution"
  value       = module.hosting.cloudfront_domain_name
}
```
## Step 7: Replicate for Staging and Production

Copy the dev environment structure for staging and prod:

```bash
# Copy dev to staging
xcopy infra\terraform\environments\dev infra\terraform\environments\staging\ /E /I

# Copy dev to prod  
xcopy infra\terraform\environments\dev infra\terraform\environments\prod\ /E /I
```

Update the backend.hcl and variables.tf files for each environment:

**Staging:** Change `key = "staging/terraform.tfstate"` and `environment = "staging"`
**Production:** Change `key = "prod/terraform.tfstate"` and `environment = "prod"`

---

# PHASE 3: Deployment and Validation
## Step 8: Deploy Development Environment

```bash
# Set AWS profile for development
set AWS_PROFILE=terraform-dev

# Navigate to dev environment
cd infra\terraform\environments\dev

# Initialize Terraform
terraform init -backend-config=backend.hcl

# Plan deployment
terraform plan

# Apply infrastructure
terraform apply
```

## Step 9: Deploy Staging Environment

```bash
# Navigate to staging environment
cd ..\staging

# Initialize Terraform
terraform init -backend-config=backend.hcl

# Plan and apply
terraform plan
terraform apply
```

## Step 10: Validate Infrastructure

### Test Resource Creation

```bash
# Check DynamoDB table
aws dynamodb describe-table --table-name notesapp-notes-dev

# Check Cognito User Pool
aws cognito-idp describe-user-pool --user-pool-id <user-pool-id>

# Check S3 bucket
aws s3 ls | findstr notesapp-frontend-dev

# Check CloudFront distribution
aws cloudfront list-distributions
```

### Test IAM Permissions

```bash
# Test Lambda execution role
aws sts assume-role --role-arn <lambda-execution-role-arn> --role-session-name test-session

# Verify tag-based access control
aws dynamodb describe-table --table-name notesapp-notes-prod
# Should fail with access denied for dev profile
```

---

# PHASE 4: Security Validation

## Step 11: Verify IAM Security Model

### Test Environment Isolation

```bash
# Using dev profile, try to access prod resources (should fail)
set AWS_PROFILE=terraform-dev
aws dynamodb scan --table-name notesapp-notes-prod
# Expected: Access Denied

# Test proper dev access
aws dynamodb scan --table-name notesapp-notes-dev
# Expected: Success (empty table)
```

### Validate Resource Tagging

```bash
# Check all resources have proper tags
aws resourcegroupstaggingapi get-resources --tag-filters Key=environment,Values=dev
```

## Step 12: Test Production Deployment Protection

```bash
# Try to deploy prod locally (should be blocked)
cd ..\prod
terraform init -backend-config=backend.hcl
terraform plan  # Should work (read-only)
terraform apply # Should fail with CI/CD protection
```

---

# 📊 Infrastructure Validation Checklist

## Core Infrastructure

- [ ] DynamoDB tables created with proper naming
- [ ] Cognito User Pools configured with security policies
- [ ] S3 buckets created with encryption and versioning
- [ ] CloudFront distributions configured with OAC
- [ ] IAM roles created with least-privilege permissions

## Security Validation

- [ ] Environment isolation working (dev cannot access prod)
- [ ] Resource tagging enforced across all resources
- [ ] Production deployment blocked from local execution
- [ ] State files encrypted and locked properly
- [ ] Sensitive data not stored in Terraform state

## Environment Consistency

- [ ] All three environments (dev/staging/prod) deployable
- [ ] Configuration differences properly managed
- [ ] Resource naming consistent across environments
- [ ] Tags applied uniformly

---
