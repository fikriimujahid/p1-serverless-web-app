# 📘 PHASE 2 — Infrastructure as Code (Foundation) Guideline

**Objective**: Establish a robust, reproducible, and secure infrastructure foundation using Terraform. This phase focuses on setting up environment isolation, state management, and the core IAM security model before any application code is written.

**References**:
*   `step.md`: High-level phase definition.
*   `docs/01-architecture.md`: Architecture decisions (Serverless, DynamoDB, Cognito).
*   `docs/02-infra.md`: Infrastructure strategy (Terraform structure, State management, Environment isolation).
*   `docs/02-iam.md`: Security model (Roles, Permissions).

---

## 🛠 Prerequisites

Before starting, ensure you have:
1.  **Terraform** (v1.5+) installed.
2.  **AWS CLI v2** installed and configured with Administrator credentials.
3.  **Git** initialized in the project root.
4.  **VS Code** (or your preferred editor) open.

---

## 🚀 Step-by-Step Implementation

### Step 1: Directory Structure Analysis & Setup

**Goal**: Create the modular directory structure defined in `docs/02-infra.md`.

1.  Navigate to your project root.
2.  Create the following directory hierarchy (delete any existing `infra` folder content if it conflicts):

    ```text
    infra/
    └── terraform/
        ├── main.tf              # Root module entry point
        ├── variables.tf         # Global variables (project, environment)
        ├── outputs.tf           # Global outputs (API endpoints, User Pool IDs)
        ├── backend.tf           # Remote state configuration
        ├── versions.tf          # Provider constraints
        ├── envs/                # Environment-specific variable files
        │   ├── dev.tfvars       # Dev config
        │   ├── staging.tfvars   # Staging config
        │   └── prod.tfvars      # Prod config
        └── modules/             # Reusable logic
            ├── iam/             # Roles & Policies
            ├── database/        # DynamoDB Tables
            ├── compute/         # Lambda/APIGW wrappers
            ├── auth/            # Cognito User Pools
            └── security/        # KMS & Secrets
    ```

### Step 2: Remote State Management (Bootstrap)

**Goal**: Solve the "Chicken & Egg" problem. Terraform needs a place to store its state file *before* it can create infrastructure.

1.  **Manual Action (AWS Console or Script)**:
    *   **Create S3 Bucket**: Name it `[project]-terraform-state-[random-suffix]` (e.g., `p1-notes-app-tf-state-123`).
        *   Region: Same as your target region (e.g., `us-east-1`).
        *   Versioning: **Enabled** (Critical for recovery).
        *   Encryption: **Enabled** (SSE-S3).
    *   **Create DynamoDB Table**: Name it `[project]-terraform-locks`.
        *   Partition Key: `LockID` (String).

2.  **Configure `infra/terraform/backend.tf`**:
    ```hcl
    terraform {
      backend "s3" {
        bucket         = "[your-bucket-name]"
        key            = "terraform.tfstate" # Will be overridden mostly, but good default
        region         = "[your-region]"
        encrypt        = true
        dynamodb_table = "[your-lock-table-name]"
      }
    }
    ```

### Step 3: Environment Isolation & Tagging

**Goal**: Implement the **Single-Account, Tag-Based Isolation Model** (`docs/02-infra.md`).

1.  **Define Variables (`infra/terraform/variables.tf`)**:
    *   `project_name` (string, default = "personal-notes")
    *   `environment` (string) - **NO default** (Forces you to specify it).

2.  **Create Environment Configs**:
    *   **`envs/dev.tfvars`**:
        ```hcl
        environment = "dev"
        ```
    *   **`envs/prod.tfvars`**:
        ```hcl
        environment = "prod"
        ```

3.  **Root Module (`infra/terraform/main.tf`)**:
    *   Set up the `locals` block for common tags.
    ```hcl
    locals {
      common_tags = {
        Project     = var.project_name
        Environment = var.environment
        ManagedBy   = "Terraform"
      }
    }
    ```

### Step 4: IAM Foundation (Critical Security)

**Goal**: Implement the roles from `docs/02-iam.md`.

1.  **Develop `modules/iam/main.tf`**:
    *   **DeveloperRole**:
        *   Create `aws_iam_role` assumable by your AWS Account/User.
        *   Create `aws_iam_policy` allowing `lambda:*`, `dynamodb:*` on resources with suffix `*-${var.environment}`.
    *   **DeploymentRole** (for CI/CD):
        *   Allow assuming from OIDC provider (GitHub Actions).
        *   Broad permissions restricted to the project resources.
    *   **LambdaExecutionRole**:
        *   Assumable by `lambda.amazonaws.com`.
        *   Basic execution + DynamoDB access (scoped to app tables).

2.  **Instantiate in Root (`main.tf`)**:
    ```hcl
    module "iam" {
      source      = "./modules/iam"
      environment = var.environment
      # ... pass other vars
    }
    ```

### Step 5: Core Services Implementation

**Goal**: Create the foundation for Auth and Data.

1.  **Database (`modules/database`)**:
    *   Create `aws_dynamodb_table` named `notes-app-${var.environment}`.
    *   Billing Mode: `PAY_PER_REQUEST` (Serverless).
    *   Attribute: `PK` (String), `SK` (String).

2.  **Auth (`modules/auth`)**:
    *   Create `aws_cognito_user_pool` named `notes-user-pool-${var.environment}`.
    *   Create `aws_cognito_user_pool_client` (App Client).
    *   Output: `user_pool_id`, `client_id`.

3.  **Compute Support (`modules/compute`)**:
    *   Create `aws_cloudwatch_log_group` for future Lambda functions (to control retention).
    *   *Note*: The actual Lambda Functions will be deployed via SAM or Terraform later, but the Log Groups should be managed here.

### Step 6: Deployment & Verification

**Goal**: Validate the infrastructure code.

1.  **Initialize**:
    ```bash
    cd infra/terraform
    terraform init -backend-config="key=dev/terraform.tfstate"
    ```
    *   *Note*: We use the same backend bucket, but different keys for different environments. Actually, better practice for single account is often:
    ```bash
    # For Dev
    terraform workspace select dev || terraform workspace new dev
    ```
    *   *Correction per `docs/02-infra.md`*: The doc suggests `backend-config="key=${env}/terraform.tfstate"`.
    *   Command: `terraform init -backend-config="key=dev/terraform.tfstate"`

2.  **Plan**:
    ```bash
    terraform plan -var-file="envs/dev.tfvars"
    ```

3.  **Apply**:
    ```bash
    terraform apply -var-file="envs/dev.tfvars"
    ```

4.  **Verify**:
    *   Go to AWS Console -> DynamoDB. Do you see `notes-app-dev`?
    *   Go to AWS Console -> Cognito. Do you see `notes-user-pool-dev`?
    *   Check Tags: Does `Environment` = `dev`?

---

## 📝 Configuration Reference

**`infra/terraform/envs/dev.tfvars`**:
```hcl
environment          = "dev"
dynamodb_billing_mode = "PAY_PER_REQUEST"
log_retention_days    = 7
```

**`infra/terraform/envs/prod.tfvars`**:
```hcl
environment          = "prod"
dynamodb_billing_mode = "PROVISIONED" # Example variation
log_retention_days    = 30
```

---

## ✅ Deliverable Checklist (Exit Criteria)

*   [ ] Directory structure matches `docs/02-infra.md`.
*   [ ] `terraform init` succeeds with S3 backend.
*   [ ] `terraform plan` shows correct resource names (`*-dev`).
*   [ ] IAM Roles (`DeveloperRole`, `LambdaExecutionRole`) exist and have scoped policies.
*   [ ] Sensitive data is NOT committed (use `*.auto.tfvars` or env vars for secrets).
