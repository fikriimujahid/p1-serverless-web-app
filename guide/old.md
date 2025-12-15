# 📘 PHASE 2 — Infrastructure as Code (Foundation) Guideline  
**Single AWS Account · Prod-Safe · Terraform-First Architecture**

---

## 🎯 Objective

Establish a **production-grade, reusable, and secure Terraform foundation** using a **single AWS account**, while enforcing:

- ✅ Local Terraform allowed for **dev & staging**
- 🚫 **Prod Terraform apply is impossible locally**
- ✅ **Prod deploys only via CI/CD**
- ✅ Strong IAM, backend, and Terraform guardrails
- ✅ Alignment with AWS Well-Architected Framework

This phase focuses on **environment isolation, state safety, and IAM trust boundaries** before any application code is introduced.

---

## 🛠 Prerequisites

1. Terraform **v1.5+**
2. AWS CLI **v2**
3. Git repository initialized
4. Existing Route53 Hosted Zone (e.g. `fikri.dev`)
5. Existing ACM Certificate in **us-east-1** (for CloudFront)
6. Terraform backend resources already created:
   - S3 state bucket
   - DynamoDB lock table
7. IAM roles created:
   - `TerraformDevRole`
   - `TerraformProdRole` (CI/CD only)
   - `CICDRunnerRole`

---

## 🧱 Step 1: Directory Structure (Environment-Safe)

### 🔴 Key Design Change (from previous version)

❌ **No single root with tfvars switching**  
✅ **Folder-based environments (hard isolation)**

This prevents accidental prod execution and is CI/CD-friendly.

```text
infra/
└── terraform/
    ├── modules/                 # Reusable building blocks (no env logic)
    │   ├── iam/
    │   ├── dynamodb/
    │   ├── cognito/
    │   ├── hosting/             # S3 + CloudFront
    │   ├── route53/
    │   └── acm/
    │
    ├── globals/
    │   ├── versions.tf          # Terraform & provider constraints
    │   ├── providers.tf         # AWS provider (assume_role)
    │   └── naming.tf            # Naming & tagging conventions
    │
    └── environments/
        ├── dev/
        │   ├── backend.tf
        │   ├── main.tf
        │   ├── variables.tf
        │   ├── outputs.tf
        │   └── terraform.tfvars
        │
        ├── staging/
        └── prod/
````

✔ Clear blast radius
✔ One backend per environment
✔ Impossible to “accidentally” apply prod

---

## 🔐 Step 2: Remote State (Security & Reliability)

### Backend Rules

| Environment | State Key                           | Who Can Access              |
| ----------- | ----------------------------------- | --------------------------- |
| dev         | `project/dev/terraform.tfstate`     | TerraformDevRole            |
| staging     | `project/staging/terraform.tfstate` | TerraformDevRole            |
| prod        | `project/prod/terraform.tfstate`    | TerraformProdRole (CI only) |

### Example `backend.tf` (per environment)

```hcl
terraform {
  backend "s3" {
    bucket         = "notesapp-terraform-state-fikri"
    key            = "notesapp/dev/terraform.tfstate"
    region         = "ap-southeast-1"
    dynamodb_table = "notesapp-terraform-locks"
    encrypt        = true
  }
}
```

🚫 Developers have **no access** to prod state
🚫 Prevents state corruption or accidental prod apply

---

## 🧩 Step 3: Providers & Role Assumption (MANDATORY)

### globals/providers.tf

```hcl
provider "aws" {
  region = var.region

  assume_role {
    role_arn = var.terraform_role_arn
  }
}
```

### Environment Variables

**dev / staging**

```hcl
terraform_role_arn = "arn:aws:iam::<ACCOUNT_ID>:role/TerraformDevRole"
```

**prod**

```hcl
terraform_role_arn = "arn:aws:iam::<ACCOUNT_ID>:role/TerraformProdRole"
```

**CI/CD (GitHub Actions using OIDC)**

CI pipelines run in GitHub Actions and should use the `CICDRunnerRole` via the GitHub OIDC provider. Configure the provider in IAM (provider URL `https://token.actions.githubusercontent.com`, audience `sts.amazonaws.com`) and allow the `CICDRunnerRole` to assume (or access) the dev/staging backend. Example uses:

- For pipeline runs that manage dev/staging: assume `CICDRunnerRole` (OIDC) and either assume `TerraformDevRole` or use `CICDRunnerRole`'s permissions which are limited to the dev/staging S3 state prefixes and DynamoDB lock table.
- For prod: pipeline must assume `TerraformProdRole` (trust restricted to `CICDRunnerRole`), keeping prod isolated.

Ensure developers cannot assume `TerraformProdRole` and that `TerraformDevRole` trust includes both developer users and `CICDRunnerRole` so pipelines and dev runs use the same dev/staging trust boundary.

✔ Same code
✔ Different trust boundary
✔ IAM enforces safety

---

## 🚨 Step 4: Terraform Prod Guard (NON-NEGOTIABLE)

Inside `environments/prod/main.tf`:

```hcl
data "aws_caller_identity" "current" {}

locals {
  expected_role_arn = "arn:aws:iam::<ACCOUNT_ID>:role/TerraformProdRole"
}

resource "null_resource" "block_local_prod" {
  count = data.aws_caller_identity.current.arn == local.expected_role_arn ? 0 : 1

  provisioner "local-exec" {
    command = "echo '🚨 PROD APPLY BLOCKED — CI/CD ONLY' && exit 1"
  }
}
```

✔ Blocks local execution
✔ Blocks wrong AWS profile
✔ Visible, fast failure

---

## 🔐 Step 5: IAM & Security Model (Least Privilege)

### Core Rules

* ❌ No Terraform using IAM users
* ❌ No wildcard resource access
* ✅ All resources tagged with `environment`
* ✅ Explicit deny for prod on developer roles

### Mandatory Tags (Global)

```hcl
locals {
  common_tags = {
    project     = var.project
    environment = var.environment
    managed_by  = "terraform"
  }
}
```

Every module **must apply these tags**.

---

## 🧱 Step 6: Core Modules (Production Defaults)

### DynamoDB (`modules/dynamodb`)

* Encryption enabled
* PITR enabled
* Billing mode variable-driven
* `prevent_destroy = true` in prod

### Hosting (`modules/hosting`)

* S3 private (no public access)
* CloudFront with OAC
* TLS ≥ `TLSv1.2_2021`
* HTTPS redirect enforced

### Auth (`modules/cognito`)

* Strong password policy
* MFA optional (required in prod via variable)
* Email/phone verification enabled

---

## 💰 Step 7: Cost & Governance Controls

### Budgets (Per Environment)

* Dev: $10
* Staging: $25
* Prod: $50+

Notifications at:

* 80%
* 100%

---

## 🚀 Step 8: Deployment Rules

### Allowed

| Command                 | Dev/Staging | Prod |
| ----------------------- | ----------- | ---- |
| terraform plan          | ✅ local     | ❌    |
| terraform apply         | ✅ local     | ❌    |
| terraform apply (CI/CD) | ❌           | ✅    |

### Dev Example

```bash
cd infra/terraform/environments/dev
terraform init
terraform apply
```

### Prod Example (CI/CD ONLY)

```bash
terraform apply -auto-approve
```

---

## 🔍 Step 9: Verification Checklist

* [ ] Terraform state encrypted & locked
* [ ] Prod backend inaccessible locally
* [ ] Prod guard blocks local execution
* [ ] IAM explicit deny on prod enforced
* [ ] CloudFront uses OAC
* [ ] S3 is private
* [ ] DynamoDB PITR enabled
* [ ] All resources tagged
* [ ] Budgets active

---

## 🧠 Key Architectural Decisions (Summary)

| Decision                  | Why                             |
| ------------------------- | ------------------------------- |
| Folder-based environments | Prevent prod accidents          |
| IAM role per environment  | Strong isolation in one account |
| CI-only prod role         | Human-proof safety              |
| Terraform guard           | Fail-fast protection            |
| Explicit deny via tags    | IAM-enforced prod block         |

---
