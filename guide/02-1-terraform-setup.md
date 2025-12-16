# Complete AWS & Terraform Setup Guide
**Single AWS Account · Production-Safe · CI/CD Ready**

## 📋 Prerequisites
1. AWS Account with root access
2. Terraform **v1.5+**
3. AWS CLI **v2**
4. Git repository initialized
5. GitHub repository for CI/CD

---

# PHASE 1: Manual Terraform (AWS Console)
## 1.1: Create Terraform Admin User
1. Login to AWS Console as **Root**
2. Navigate to **IAM → Users → Create user**
3. Configure user:
   - **User name**: `terraform-admin`
   - **Console access**: Enabled
   - **Password**: Auto-generated or custom
4. Attach permissions:
   - `AdministratorAccess`

> This user will be locked down after Terraform setup
## 1.2: Create Terraform Backend Resources
### 1.2.1 Create S3 Bucket (State Storage)
1. Navigate to **S3 → Create bucket**
2. Configure:
   - **Bucket name**: `<project>-terraform-state-<unique-suffix>`
   - **Example**: `p1-serverless-web-app-terraform-state-fikri`
   - **Region**: Same as your Terraform region
   - ✅ **Versioning**: Enabled
   - ✅ **Default encryption**: SSE-S3
   - ✅ **Block all public access**: Enabled
### 1.2.2 Create DynamoDB Table (State Locking)
1. Navigate to **DynamoDB → Create table**
2. Configure:
   - **Table name**: `<project>-terraform-locks`
   - **Example**: `p1-serverless-web-app-terraform-locks`
   - **Partition key**: `LockID` (String)
   - **Billing mode**: On-demand

---

# PHASE 2: Terraform Infrastructure Setup
## 2.1: Configure Terraform Admin
```bash
aws configure --profile terraform-admin
# Enter Access Key ID and Secret Access Key for terraform-admin user
```
## 2.2: Setup Terraform Configuration (From Scratch)
### 2.2.1 Create Terraform Directory Structure
#### 2.2.1.1: Create Directory Structure
Create the Terraform Terraform directory:
**Git Bash/WSL:**
```bash
mkdir -p infra/terraform/environments/bootstrap
cd infra/terraform/environments/bootstrap
```
#### 2.2.1.2: Create variables.tf
Create a new file named `variables.tf` with the following content:
```hcl
variable "project" {
  description = "Project name"
  type        = string
  default     = "p1-serverless-web-app"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  type        = string
}

variable "terraform_locks_table" {
  description = "DynamoDB table for Terraform locks"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository in format owner/repo"
  type        = string
}
```
#### 2.2.1.3: Create main.tf
Create a new file named `main.tf` with the following content:

```hcl
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

# Create IAM roles using Terraform admin credentials
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
```
#### 2.2.1.4: Create terraform.tfvars.example
Create a new file named `terraform.tfvars.example` (template with example values):

```hcl
project                 = "p1-serverless-web-app"
aws_region             = "us-east-1"
terraform_state_bucket = "p1-serverless-web-app-terraform-state-fikri"
terraform_locks_table  = "p1-serverless-web-app-terraform-locks"
github_repo            = "your-username/p1-serverless-web-app"
```
#### 2.2.1.5: Create terraform.tfvars (Actual Configuration)
Now create the actual configuration file by copying the example:
**Git Bash/WSL**
```bash
cd infra/terraform/environments/bootstrap
cp terraform.tfvars.example terraform.tfvars
```
#### 2.2.1.6: Edit terraform.tfvars with Your Actual Values
Open `terraform.tfvars` and replace the example values with YOUR actual values:

```hcl
# Replace with your actual project name
project = "myapp"

# Use the same region where you created S3 and DynamoDB in Step 2
aws_region = "us-east-1"

# Use the EXACT S3 bucket name from Step 2.1
terraform_state_bucket = "myapp-terraform-state-abc123"

# Use the EXACT DynamoDB table name from Step 2.2
terraform_locks_table = "myapp-terraform-locks"

# Use YOUR GitHub username and repository name
github_repo = "john-doe/p1-serverless-web-app"
```

**⚠️ Important Rules:**
- Keep all values in quotes `"value"`
- Use EXACT names from AWS Console (Step 2)
- GitHub repo format: `your-github-username/repository-name`
- Save the file after editing
### 2.2.2 Create IAM Roles and OIDC Provider
```bash
# Set AWS profile
set AWS_PROFILE=terraform-admin

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
### 2.2.3 Save Terraform Outputs
After `terraform apply` completes, save the output values. You'll need these for future steps:

```bash
# Display all outputs
terraform output

# Save to a file for reference
terraform output > bootstrap-outputs.txt
```

You should see outputs like:
```
cicd_runner_role_arn = "arn:aws:iam::123456789012:role/CICDRunnerRole"
github_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
terraform_dev_role_arn = "arn:aws:iam::123456789012:role/TerraformDevRole"
terraform_prod_role_arn = "arn:aws:iam::123456789012:role/TerraformProdRole"
```

---
## 2.3: Configure AWS CLI Profiles for Dev & Prod
### 2.3.1: Add AWS CLI Configuration
Edit your AWS CLI config file:

**Windows:**
Open: `C:\Users\<YourUsername>\.aws\config`

**Mac/Linux:**
Open: `~/.aws/config`

Add these profiles at the end:

```ini
[profile terraform-dev]
role_arn = arn:aws:iam::YOUR-ACCOUNT-ID:role/TerraformDevRole
source_profile = terraform-admin
external_id = terraform-dev

[profile terraform-prod]
role_arn = arn:aws:iam::YOUR-ACCOUNT-ID:role/TerraformProdRole
source_profile = terraform-admin
external_id = terraform-prod
```

**Replace `YOUR-ACCOUNT-ID`** with your actual AWS Account ID from Step 2.3.
### 2.3.2: Test AWS CLI Profiles
Verify the profiles work:

```bash
# Test dev profile
aws sts get-caller-identity --profile terraform-dev

# Test prod profile
aws sts get-caller-identity --profile terraform-prod
```

Both should return your Account ID and role ARNs.

---

# PHASE 3: Development Environment Setup
## 3.1: Create Dev Environment Directory Structure
### 3.1.1: Create Dev Directory
```bash
mkdir -p infra/terraform/environments/dev
cd infra/terraform/environments/dev
```
### 3.1.2: Create Dev variables.tf
Create `infra/terraform/environments/dev/variables.tf`:

```hcl
variable "project" {
  description = "Project name"
  type        = string
  default     = "p1-serverless-web-app"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "terraform_state_bucket" {
  description = "S3 bucket for Terraform state"
  type        = string
}

variable "terraform_locks_table" {
  description = "DynamoDB table for Terraform locks"
  type        = string
}
```
### 3.1.3: Create Dev backend.hcl
Create `infra/terraform/environments/dev/backend.hcl`:
```hcl
bucket         = "terraform-731099197523"
key            = "p1/dev/terraform.tfstate"
region         = "ap-southeast-1"
use_lockfile   = true
encrypt        = true
profile        = "terraform-dev"
```
### 3.1.4: Create Dev terraform.tfvars.example
Create `infra/terraform/environments/dev/terraform.tfvars.example`:
```hcl
project                 = "p1-serverless-web-app"
environment            = "dev"
aws_region             = "us-east-1"
terraform_state_bucket = "p1-serverless-web-app-terraform-state-fikri"
terraform_locks_table  = "p1-serverless-web-app-terraform-locks"
```
### 3.1.5: Create Dev terraform.tfvars
Copy the example to create the actual file:
```bash
cd infra/terraform/environments/dev
cp terraform.tfvars.example terraform.tfvars
```
### 3.1.6: Edit Dev terraform.tfvars
Open `terraform.tfvars` and update with your values:
```hcl
project                 = "myapp"
environment            = "dev"
aws_region             = "us-east-1"
terraform_state_bucket = "myapp-terraform-state-abc123"
terraform_locks_table  = "myapp-terraform-locks"
```
### 3.1.7: Create Dev main.tf
Create `infra/terraform/environments/dev/main.tf`:
```hcl
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
```
### 3.1.8: Create Dev outputs.tf
Create `infra/terraform/environments/dev/outputs.tf`:
```hcl
# Add your outputs here as you create resources
# Example:
# output "api_gateway_url" {
#   description = "API Gateway endpoint URL"
#   value       = aws_api_gateway_rest_api.main.invoke_url
# }
```
## 3.2: Initialize Dev Environment
### 3.2.1: Initialize Terraform for Dev
```bash
cd infra/terraform/environments/dev

# Initialize with backend configuration
terraform init -backend-config=backend.hcl
```

You should see:
```
Terraform has been successfully configured!
```
### 3.2.2: Validate Dev Configuration
```bash
# Validate the configuration
terraform validate
```

Should output:
```
Success! The configuration is valid.
```
### 3.2.3: Plan Dev Infrastructure
```bash
# See what will be created
terraform plan
```
### 3.2.4: Apply Dev Infrastructure
```bash
# Create dev infrastructure
terraform apply
```

Review the plan and type `yes` to confirm.

---
# PHASE 4: Staging Environment Setup (Optional)
If you need a staging environment for pre-production testing, follow the same structure as dev:

## 4.1: Create Staging Directory

```bash
mkdir -p infra/terraform/environments/staging
```

## 4.2: Create Staging Files

Copy dev environment files to staging and update as needed:

```bash
# Copy files from dev to staging
cd infra/terraform/environments
cp -r dev staging

cd staging

# Edit terraform.tfvars with staging-specific values
# Change environment = "staging" instead of "dev"
```

## 4.3: Initialize Staging

```bash
cd infra/terraform/environments/staging

terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

---

# PHASE 5: Production Environment Setup

## 5.1: Create Prod Directory

```bash
mkdir -p infra/terraform/environments/prod
```

## 5.2: Create Prod Files

```bash
# Copy files from dev to prod
cd infra/terraform/environments
cp -r dev prod

cd prod

# Edit terraform.tfvars with production-specific values
# Change environment = "prod" instead of "dev"
```

### 5.2.1: Edit Prod terraform.tfvars

```hcl
project                 = "myapp"
environment            = "prod"
aws_region             = "us-east-1"
terraform_state_bucket = "myapp-terraform-state-abc123"
terraform_locks_table  = "myapp-terraform-locks"
```

### 5.2.2: Edit Prod main.tf

Update the profile to use terraform-prod:

```hcl
provider "aws" {
  region  = var.aws_region
  profile = "terraform-prod"  # Changed from terraform-dev

  default_tags {
    tags = {
      project     = var.project
      environment = var.environment
      managed_by  = "terraform"
    }
  }
}
```

## 5.3: Initialize Prod

```bash
cd infra/terraform/environments/prod

terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

⚠️ **IMPORTANT**: Production should ideally be deployed only through CI/CD (GitHub Actions), not locally.

---

# Summary: Directory Structure After Setup

Your project should now have this structure:

```
infra/terraform/
├── environments/
│   ├── bootstrap/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   └── terraform.tfvars.example
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── backend.hcl
│   │   ├── terraform.tfvars
│   │   └── terraform.tfvars.example
│   ├── staging/ (optional)
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── backend.hcl
│   │   ├── terraform.tfvars
│   │   └── terraform.tfvars.example
│   └── prod/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── backend.hcl
│       ├── terraform.tfvars
│       └── terraform.tfvars.example
└── modules/
    └── iam-roles/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

---

# Next Steps

1. ✅ Terraform environment created with IAM roles and OIDC provider
2. ✅ Dev environment initialized and ready for development
3. ✅ Staging environment available for testing (optional)
4. ✅ Prod environment initialized for production deployment

**Now you can:**
- Start building infrastructure resources in `infra/terraform/environments/dev/main.tf`
- Test changes in dev before promoting to prod
- Use CI/CD for automated production deployments
- Scale to multiple AWS accounts if needed in the future

