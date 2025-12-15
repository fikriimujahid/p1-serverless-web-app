# 🚀 Complete AWS & Terraform Setup Guide
**Single AWS Account · Production-Safe · CI/CD Ready**

## 🎯 Objective

Establish a **production-grade, secure Terraform foundation** with the following guarantees:

- ✅ Dev and staging may run Terraform locally
- 🚫 Production Terraform **never** executes locally
- ✅ Production deployments are **CI/CD only**
- ✅ Terraform state is remote, encrypted, and locked
- ✅ IAM, Terraform, and backend enforce safety together

---

## 🔴 Security Principles

- ❌ AWS Root user used **once** and never again
- ❌ No local user has production Terraform permissions
- ❌ No production state access from local machines
- ✅ Production Terraform role is **CI/CD only**
- ✅ Explicit IAM denies protect production resources

---

## 📋 Prerequisites

1. AWS Account with root access
2. Terraform **v1.5+**
3. AWS CLI **v2**
4. Git repository initialized
5. GitHub repository for CI/CD

---

# PHASE 1: Manual Bootstrap (AWS Console)

## Step 1: Create Bootstrap Admin User

**⚠️ Use AWS Root account for this step only**

1. Login to AWS Console as **Root**
2. Navigate to **IAM → Users → Create user**
3. Configure user:
   - **User name**: `bootstrap-admin`
   - **Console access**: Enabled
   - **Password**: Auto-generated or custom
4. Attach permissions:
   - `AdministratorAccess`

> This user will be locked down after Terraform setup

## Step 2: Create Terraform Backend Resources

**⚠️ These cannot be managed by Terraform initially**

### 2.1 Create S3 Bucket (State Storage)

1. Navigate to **S3 → Create bucket**
2. Configure:
   - **Bucket name**: `<project>-terraform-state-<unique-suffix>`
   - **Example**: `notesapp-terraform-state-fikri`
   - **Region**: Same as your Terraform region
   - ✅ **Versioning**: Enabled
   - ✅ **Default encryption**: SSE-S3
   - ✅ **Block all public access**: Enabled

### 2.2 Create DynamoDB Table (State Locking)

1. Navigate to **DynamoDB → Create table**
2. Configure:
   - **Table name**: `<project>-terraform-locks`
   - **Example**: `notesapp-terraform-locks`
   - **Partition key**: `LockID` (String)
   - **Billing mode**: On-demand

---

# PHASE 2: Terraform Infrastructure Setup

## Step 3: Configure Bootstrap Admin

```bash
aws configure --profile bootstrap-admin
# Enter Access Key ID and Secret Access Key for bootstrap-admin user
```

## Step 4: Setup Terraform Configuration

### 4.1 Update Bootstrap Configuration

Edit `infra/terraform/environments/bootstrap/terraform.tfvars.example`:

```hcl
project                 = "notesapp"
aws_region             = "us-east-1"
terraform_state_bucket = "notesapp-terraform-state-fikri"
terraform_locks_table  = "notesapp-terraform-locks"
github_repo            = "your-username/p1-serverless-web-app"
```

Copy to `terraform.tfvars`:
```bash
cd infra/terraform/environments/bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your actual values
```

### 4.2 Create IAM Roles and OIDC Provider

```bash
# Set AWS profile
set AWS_PROFILE=bootstrap-admin

# Initialize and create roles
terraform init
terraform plan
terraform apply
```

This creates:
- **TerraformDevRole**: Local dev/staging access
- **TerraformProdRole**: CI/CD production only
- **CICDRunnerRole**: GitHub Actions pipeline
- **GitHub OIDC Provider**: For secure CI/CD

## Step 5: Configure AWS CLI Profiles

Add to `~/.aws/config`:

```ini
[profile terraform-dev]
role_arn = arn:aws:iam::YOUR-ACCOUNT-ID:role/TerraformDevRole
source_profile = bootstrap-admin
external_id = terraform-dev

[profile terraform-prod]
role_arn = arn:aws:iam::YOUR-ACCOUNT-ID:role/TerraformProdRole
source_profile = cicd-runner
```

Replace `YOUR-ACCOUNT-ID` with your actual AWS account ID.

---

# PHASE 3: Environment Testing & Validation

## Step 6: Test Development Environment

```bash
# Switch to dev profile
set AWS_PROFILE=terraform-dev

# Test dev environment
cd infra/terraform/environments/dev
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

## Step 7: Test Production Protection

```bash
# Try production locally (should fail)
cd ../prod
terraform init -backend-config=backend.hcl
terraform plan  # This works (read-only)
terraform apply # This FAILS with "🚨 PROD APPLY BLOCKED — CI/CD ONLY"
```

## Step 8: Setup GitHub Actions CI/CD

### 8.1 Configure Repository Secrets

In your GitHub repository, add these secrets:
- `AWS_PROD_ROLE_ARN`: `arn:aws:iam::YOUR-ACCOUNT-ID:role/TerraformProdRole`
- `AWS_DEV_ROLE_ARN`: `arn:aws:iam::YOUR-ACCOUNT-ID:role/TerraformDevRole`

### 8.2 Test CI/CD Pipeline

1. Push changes to trigger workflows
2. Verify dev/staging plans work on PRs
3. Verify production deploys work on main branch

---

# PHASE 4: Security Lockdown

## Step 9: Lock Down Bootstrap Admin

**⚠️ Only after confirming IAM roles work**

1. **Remove AdministratorAccess** from bootstrap-admin user
2. **Delete access keys** for bootstrap-admin user
3. **Enable MFA** for bootstrap-admin user
4. **Keep as break-glass emergency access only**

---

# 🏗️ Architecture Overview

## Directory Structure

```
infra/terraform/
├── modules/
│   └── iam-roles/          # IAM roles module
├── environments/
│   ├── bootstrap/          # One-time IAM setup
│   ├── dev/               # Development environment
│   ├── staging/           # Staging environment
│   └── prod/              # Production (CI/CD only)
└── .github/workflows/     # GitHub Actions
```

## IAM Roles & Access

| Role | Purpose | Access Method |
|------|---------|---------------|
| TerraformDevRole | Dev/staging Terraform | Local developers |
| TerraformProdRole | Production Terraform | CI/CD only |
| CICDRunnerRole | GitHub Actions | OIDC (no keys) |

## Backend Access Control

| Environment | State Key | Access |
|-------------|-----------|--------|
| Dev | `dev/terraform.tfstate` | TerraformDevRole |
| Staging | `staging/terraform.tfstate` | TerraformDevRole |
| Prod | `prod/terraform.tfstate` | TerraformProdRole only |

## Security Features

### 1. IAM Tag-Based Protection
```json
{
  "Effect": "Deny",
  "Action": "*",
  "Resource": "*",
  "Condition": {
    "StringEquals": {
      "aws:ResourceTag/environment": "prod"
    }
  }
}
```

### 2. Terraform-Level Protection
```hcl
resource "null_resource" "block_non_ci" {
  count = data.aws_caller_identity.current.arn == local.expected_role_arn ? 0 : 1
  
  provisioner "local-exec" {
    command = "echo '🚨 PROD APPLY BLOCKED — CI/CD ONLY' && exit 1"
  }
}
```

### 3. Mandatory Resource Tagging
```hcl
tags = {
  project     = var.project
  environment = var.environment
  managed_by  = "terraform"
}
```

---

# ✅ Final Verification Checklist

- [ ] Bootstrap admin user created and configured
- [ ] S3 bucket and DynamoDB table created manually
- [ ] IAM roles created via Terraform
- [ ] AWS CLI profiles configured
- [ ] TerraformDevRole can access dev/staging
- [ ] TerraformDevRole denied prod resources
- [ ] TerraformProdRole blocks local execution
- [ ] GitHub Actions workflows configured
- [ ] CI/CD can deploy to production
- [ ] Bootstrap admin locked down

---

# 🚀 Usage Examples

## Local Development
```bash
set AWS_PROFILE=terraform-dev
cd infra/terraform/environments/dev
terraform plan
terraform apply
```

## Production Deployment
- Push to main branch
- GitHub Actions automatically deploys
- Manual approval required for production

## Emergency Access
- Use bootstrap-admin with MFA
- Only for break-glass scenarios
- Re-lock immediately after use

---

This guide ensures a secure, production-ready Terraform setup with proper environment isolation and CI/CD integration.