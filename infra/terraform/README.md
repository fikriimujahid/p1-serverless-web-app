# Terraform Infrastructure Setup

This directory contains the Terraform infrastructure for the serverless web app with proper IAM role separation and production protection.

## Directory Structure

```
terraform/
├── modules/
│   └── iam-roles/          # IAM roles module
├── environments/
│   ├── bootstrap/          # Initial IAM roles setup
│   ├── dev/               # Development environment
│   ├── staging/           # Staging environment
│   └── prod/              # Production environment (CI/CD only)
└── scripts/               # Setup scripts
```

## Setup Process

### 1. Bootstrap IAM Roles (One-time setup)

Run this **once** using bootstrap admin credentials:

```bash
cd environments/bootstrap
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform plan
terraform apply
```

### 2. Configure AWS CLI for Role Assumption

Add to your `~/.aws/config`:

```ini
[profile terraform-dev]
role_arn = arn:aws:iam::<ACCOUNT_ID>:role/TerraformDevRole
source_profile = default
external_id = terraform-dev

[profile terraform-prod]
role_arn = arn:aws:iam::<ACCOUNT_ID>:role/TerraformProdRole
source_profile = cicd-runner
```

### 3. Development/Staging Usage

```bash
# Set AWS profile
set AWS_PROFILE=terraform-dev

# Initialize and apply
cd environments/dev
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

### 4. Production Usage (CI/CD Only)

Production deployments are **blocked** for local execution. The `null_resource.block_non_ci` will fail if not executed by the CI/CD role.

## IAM Roles

| Role | Purpose | Access |
|------|---------|--------|
| TerraformDevRole | Dev/staging Terraform | Local developers |
| TerraformProdRole | Production Terraform | CI/CD only |
| CICDRunnerRole | Pipeline execution | CI system |

## Security Features

- ✅ Production resources protected by IAM tag-based deny
- ✅ Production Terraform state inaccessible locally
- ✅ Terraform-level production execution blocking
- ✅ Mandatory resource tagging enforced
- ✅ Role assumption with external ID for dev

## Mandatory Tags

All resources must include:

```hcl
tags = {
  project     = var.project
  environment = var.environment
  managed_by  = "terraform"
}
```