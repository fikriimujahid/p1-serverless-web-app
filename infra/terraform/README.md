# Terraform Infrastructure

This directory contains Terraform configurations for provisioning and managing the AWS infrastructure for the serverless web application.

## Overview

The infrastructure is organized into modular components and separate environments, following best practices for infrastructure as code (IaC).

## Directory Structure

```
terraform/
├── modules/              # Reusable Terraform modules
│   ├── auth/            # Cognito authentication resources
│   ├── database/        # DynamoDB tables
│   ├── hosting/         # S3 and CloudFront for frontend hosting
│   ├── iam/             # IAM policies
│   └── iam-roles/       # IAM roles for Lambda functions
├── environments/        # Environment-specific configurations
│   ├── bootstrap/       # S3 backend for Terraform state
│   └── dev/            # Development environment
├── scripts/            # Helper scripts for setup
│   ├── setup-bootstrap.bat
│   └── setup-dev.bat
└── variables.tf        # Root-level variable definitions
```

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) (>= 1.0)
- AWS CLI configured with appropriate credentials
- Sufficient AWS permissions to create resources

## AWS Profile Configuration

Before deploying infrastructure, configure an AWS profile with the necessary credentials.

### Adding an AWS Profile

1. **Configure a new profile**:
   ```bash
   aws configure --profile <profile-name>
   ```
   
2. **Enter your credentials** when prompted:
   - AWS Access Key ID
   - AWS Secret Access Key
   - Default region (e.g., `us-east-1`)
   - Default output format (e.g., `json`)

3. **Verify the profile**:
   ```bash
   aws sts get-caller-identity --profile <profile-name>
   ```

### Profile Configuration Files

Profiles are stored in:
- `~/.aws/credentials` (Windows: `%USERPROFILE%\.aws\credentials`)
- `~/.aws/config` (Windows: `%USERPROFILE%\.aws\config`)

**Example `~/.aws/credentials`**:
```ini
[default]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY

[dev-profile]
aws_access_key_id = YOUR_DEV_ACCESS_KEY
aws_secret_access_key = YOUR_DEV_SECRET_KEY
```

**Example `~/.aws/config`**:
```ini
[default]
region = us-east-1
output = json

[profile dev-profile]
region = us-east-1
output = json
```

## Getting Started

### 1. Bootstrap Environment

The bootstrap environment sets up the S3 bucket and DynamoDB table for storing Terraform state.

```bash
cd environments/bootstrap
terraform init
terraform plan -var="aws_profile=<profile-name>"
terraform apply -var="aws_profile=<profile-name>"
```

Or set the AWS_PROFILE environment variable:

```bash
# Linux/Mac
export AWS_PROFILE=<profile-name>

# Windows PowerShell
$env:AWS_PROFILE="<profile-name>"

# Windows Command Prompt
set AWS_PROFILE=<profile-name>

cd environments/bootstrap
terraform init
terraform plan
terraform apply
```

Or use the provided script:

```bash
cd scripts
./setup-bootstrap.bat
```

### 2. Development Environment

After bootstrapping, deploy the dev environment:

```bash
cd environments/dev
terraform init -backend-config=backend.hcl
terraform plan -var="aws_profile=<profile-name>"
terraform apply -var="aws_profile=<profile-name>"
```

Or set the AWS_PROFILE environment variable:

```bash
# Linux/Mac
export AWS_PROFILE=<profile-name>

# Windows PowerShell
$env:AWS_PROFILE="<profile-name>"

# Windows Command Prompt
set AWS_PROFILE=<profile-name>

cd environments/dev
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

Or use the provided script:

```bash
cd scripts
./setup-dev.bat
```

## Modules

### Auth Module
Provisions AWS Cognito User Pool and related authentication resources.

### Database Module
Creates DynamoDB tables for application data storage.

### Hosting Module
Sets up S3 bucket and CloudFront distribution for frontend hosting.

### IAM Module
Defines IAM policies for least-privilege access.

### IAM Roles Module
Creates IAM roles with appropriate policies for Lambda functions.

## Environment Configuration

Each environment has its own:
- `main.tf` - Main configuration
- `variables.tf` - Variable definitions
- `terraform.tfvars` - Variable values (environment-specific)
- `outputs.tf` - Output values
- `backend.hcl` - Backend configuration (for non-bootstrap environments)

## State Management

Terraform state is stored remotely in S3 with DynamoDB locking to prevent concurrent modifications:

- **S3 Bucket**: Stores state files
- **DynamoDB Table**: Provides state locking

## Common Commands

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan changes
terraform plan -var="aws_profile=<profile-name>"

# Apply changes
terraform apply -var="aws_profile=<profile-name>"

# Destroy resources
terraform destroy -var="aws_profile=<profile-name>"

# Format code
terraform fmt -recursive

# Using environment variable instead
export AWS_PROFILE=<profile-name>  # Then run commands without -var flag
```

## Best Practices

1. **Never commit** `terraform.tfvars` with sensitive values
2. Always run `terraform plan` before `apply`
3. Use workspaces or separate state files for different environments
4. Keep modules small and focused
5. Document variables and outputs
6. Use remote state for team collaboration

## Troubleshooting

### State Lock Issues
If you encounter a state lock, ensure no other Terraform operations are running. If stuck, you can force-unlock:

```bash
terraform force-unlock <lock-id>
```

### Backend Initialization
If backend configuration changes, reinitialize:

```bash
terraform init -reconfigure
```

## Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
