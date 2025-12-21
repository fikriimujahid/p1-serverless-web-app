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

## Destroying Resources

To tear down the infrastructure, you need to destroy resources in the reverse order of creation:

### 1. Destroy Development Environment

```bash
cd environments/dev

# Using environment variable (RECOMMENDED)
# Windows PowerShell
$env:AWS_PROFILE="<profile-name>"; terraform destroy

# Linux/Mac
export AWS_PROFILE=<profile-name>
terraform destroy

# Windows Command Prompt
set AWS_PROFILE=<profile-name>
terraform destroy
```

**Note**: Terraform does not accept a `-profile` flag. You must set the `AWS_PROFILE` environment variable before running the destroy command.

### 2. Destroy Bootstrap Environment (Optional)

Only destroy the bootstrap environment if you want to completely remove the Terraform state backend:

```bash
cd environments/bootstrap

# Windows PowerShell
$env:AWS_PROFILE="<profile-name>"; terraform destroy

# Linux/Mac
export AWS_PROFILE=<profile-name>
terraform destroy
```

**Warning**: Destroying the bootstrap environment will remove the S3 bucket containing your Terraform state. Make sure you have backups if needed.

## Common Commands

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Plan changes
terraform plan -var="aws_profile=<profile-name>"
# OR using environment variable
export AWS_PROFILE=<profile-name>  # Linux/Mac
$env:AWS_PROFILE="<profile-name>"  # Windows PowerShell
terraform plan

# Apply changes
terraform apply -var="aws_profile=<profile-name>"
# OR using environment variable
export AWS_PROFILE=<profile-name>  # Linux/Mac
$env:AWS_PROFILE="<profile-name>"  # Windows PowerShell
terraform apply

# Destroy resources (use environment variable)
# Windows PowerShell
$env:AWS_PROFILE="<profile-name>"; terraform destroy
# Linux/Mac
export AWS_PROFILE=<profile-name>
terraform destroy

# Format code
terraform fmt -recursive

# Show current workspace
terraform workspace show

# List all resources
terraform state list
```