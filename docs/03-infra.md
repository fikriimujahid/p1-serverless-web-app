# PHASE 3 — Infrastructure as Code (Foundation)

**Purpose of this document**
This document outlines the Infrastructure-as-Code (IaC) strategy, environment separation model, and state management approach for the serverless personal notes application. It provides the foundational infrastructure design that will be implemented in Phase 2.

---

## Executive Summary

The infrastructure is built using **Terraform** for cloud resources and **SAM (Serverless Application Model)** for serverless-specific resources. This dual-tool approach provides clarity and separation of concerns while maintaining consistency across dev, staging, and prod environments. The foundation includes networking (CDN), storage, compute, and security layers.

---

## 1. Infrastructure-as-Code Strategy

### Tooling Decision

**Primary:** Terraform (HCL)  
**Complementary:** AWS SAM (CloudFormation YAML)

### Rationale

* **Terraform:** Manages networking, IAM, DynamoDB, storage, and core infrastructure
* **SAM:** Manages Lambda functions, API Gateway, and serverless integration patterns
* **Separation:** Clearly delineates foundational infrastructure from application-specific serverless resources

### Benefits

* Reproducible deployments across environments
* Version-controlled infrastructure
* Clear ownership: platform engineers → Terraform, application engineers → SAM
* Idempotent and safely rerunnable

---

## 2. Environment Separation Model

### Three-Tier Environment Strategy

| Environment | Purpose                      | Traffic Volume | User Data | Cost Consideration      |
| ----------- | ---------------------------- | --------------- | --------- | ----------------------- |
| **dev**     | Rapid iteration and testing  | Low             | Synthetic | Always-on during work   |
| **staging** | Pre-production validation    | Medium          | Realistic | On-demand or always-on  |
| **prod**    | Live user environment        | Variable        | Real      | Always-on, optimized    |

### Separation Mechanisms

#### Isolation Strategies

1. **Account-level isolation (Recommended for enterprise)**
   * Each environment in separate AWS account
   * Not applicable for MVP due to cost

2. **Tag-based isolation (Single-account model - CHOSEN)**
   * Single AWS account
   * All resources tagged with `Environment=<env>`
   * IAM policies enforce access control based on tags
   * Cost-efficient for small deployments
   * Leverages AWS managed services (no VPC management needed)

3. **VPC-level isolation (Not needed for serverless)**
   * Would require VPC endpoints for AWS services
   * Unnecessary complexity for managed services
   * Deferred for future enterprise scaling

#### Chosen Approach: Single-Account, Tag-Based Isolation Model

```
AWS Account (Personal Notes)
├── Lambda Functions
│   ├── Handler (Environment=dev)
│   ├── Handler (Environment=staging)
│   └── Handler (Environment=prod)
├── DynamoDB Tables
│   ├── notes-table (Environment=dev)
│   ├── notes-table (Environment=staging)
│   └── notes-table (Environment=prod)
├── API Gateway APIs
│   ├── notesapi (Environment=dev)
│   ├── notesapi (Environment=staging)
│   └── notesapi (Environment=prod)
└── Cognito User Pools
    ├── notes-auth-pool (Environment=dev)
    ├── notes-auth-pool (Environment=staging)
    └── notes-auth-pool (Environment=prod)
```

**Isolation Mechanism:** IAM policies and resource naming enforce environment boundaries

### Environment Promotion Flow

```
dev → staging → prod
```

**Promotion Process:**
1. Code changes tested in dev
2. Approved changes deployed to staging
3. Integration testing in staging
4. Promoted to prod after sign-off

### Configuration Management

**Environment-Specific Variables:**

| Variable              | dev                 | staging             | prod                |
| -------------------- | ------------------- | ------------------- | ------------------- |
| DynamoDB Read Units  | 1                   | 1                  | 2                  |
| DynamoDB Write Units | 1                   | 1                  | 2                  |
| Lambda Memory        | 128 MB              | 128 MB              | 256 MB             |
| API Rate Limiting    | 1,000 req/min       | 1,000 req/min       | 10,000 req/min      |
| Backup Retention     | 7 days              | 7 days             | 30 days             |
| Logging Level        | DEBUG               | INFO                | WARN                |

**Storage Location:** `infra/terraform/envs/<env>.tfvars`

### Networking & Content Delivery

Although this architecture is serverless (No-VPC), a networking layer is implemented to route traffic securely to application endpoints.

| Component | Service | Role |
| ~ | ~ | ~ |
| **Global CDN** | Amazon CloudFront | Delivers frontend assets; handles TLS termination for `p1.fikri.dev` |
| **API Ingress** | Amazon API Gateway | REST API entry point; Custom domain mapping via API Gateway Custom Domains |
| **DNS** | Amazon Route53 | Managed Hosted Zone (`fikri.dev`) handling DNS routing for subdomains |
| **SSL/TLS** | AWS Certificate Manager | Use existing public certificate for `p1.fikri.dev` (CloudFront) |

**Networking Flow (with Custom Domain):**
```
User -> p1.fikri.dev (Route53 Alias) -> CloudFront -> S3 Bucket
User -> api.p1.fikri.dev (Route53 Alias) -> API Gateway -> Lambda Function
```

**Domain Strategy:**
* **Root Domain:** `fikri.dev` (Hosted Zone)
* **Environment Mapping:**
    * **dev:** `p1-dev.fikri.dev` (Frontend), `api.p1-dev.fikri.dev` (Backend)
    * **staging:** `p1-sta.fikri.dev` (Frontend), `api.p1-sta.fikri.dev` (Backend)
    * **prod:** `p1.fikri.dev` (Frontend), `api.p1.fikri.dev` (Backend)
* **HTTPS:** Enforced via existing ACM Certificates.

**Networking Flow:**
```
User -> CloudFront (Frontend) -> S3 Bucket
User -> API Gateway (Backend) -> Lambda Function
```

---

## 3. State Management Strategy

### State File Location

**Primary Backend:** AWS S3 + DynamoDB (Terraform Remote State)

### Configuration

```
Backend: AWS S3
├── Bucket: ${project}-terraform-state
├── Key: ${environment}/terraform.tfstate
└── Encryption: AES-256 (S3 default)

State Lock: DynamoDB
├── Table: ${project}-terraform-locks
├── Purpose: Prevent concurrent modifications
└── Consistency: Strong
```

### State Management Best Practices

| Practice                    | Implementation                                |
| --------------------------- | --------------------------------------------- |
| **Versioning**              | S3 bucket versioning enabled                  |
| **Encryption**              | S3 default AES-256 encryption                 |
| **Access Control**          | IAM policies restrict to deployment role only |
| **Locking**                 | DynamoDB state lock for concurrent safety     |
| **Backup**                  | Point-in-time recovery via S3 versioning      |
| **Isolation**               | Separate state files per environment          |
| **Rotation**                | No sensitive data in state (use AWS Secrets)  |

### Sensitive Data Handling

**Never stored in Terraform state:**
* Database passwords
* API keys
* JWT secrets
* OAuth credentials

**Retrieval method:** AWS Secrets Manager or Parameter Store
* Infrastructure fetches secrets at runtime
* Rotation handled by AWS services
* Audit trails for access

---

## 4. Terraform Module Structure

### Directory Layout

```
infra/terraform/
├── main.tf              # Root module (env-specific)
├── variables.tf         # Variable declarations
├── outputs.tf           # Output values
├── terraform.tfvars     # Environment variables (gitignored)
├── backend.tf           # Remote state configuration
├── versions.tf          # Provider versions
├── envs/
│   ├── dev.tfvars
│   ├── staging.tfvars
│   └── prod.tfvars
└── modules/
    ├── iam/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── database/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── compute/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── auth/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── security/
        │   ├── main.tf
        │   ├── variables.tf
        │   └── outputs.tf
    └── hosting/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```

### Module Responsibilities

| Module     | Manages                                                |
| ---------- | ------------------------------------------------------ |
| iam        | Roles, policies, trust relationships, tag-based access |
| database   | DynamoDB tables, indexes, backups                      |
| compute    | Lambda execution environment, API Gateway              |
| auth       | Cognito user pools, authentication                     |
| security   | Encryption, secrets management, key policies           |
| hosting    | S3 website buckets, CloudFront distribution, OAC       |

---

## 5. Deployment & Orchestration

### Prerequisites for Deployment

* Terraform v1.5 or later
* AWS CLI v2 configured with credentials
* SAM CLI for serverless deployments
* Git for version control

### Deployment Steps (High-Level)

```
1. Initialize Terraform (first-time)
   terraform init -backend-config="key=${env}/terraform.tfstate"

2. Plan changes
   terraform plan -var-file="envs/${env}.tfvars" -out=tfplan

3. Review plan (peer approval for prod)
   terraform show tfplan

4. Apply infrastructure
   terraform apply tfplan

5. Deploy serverless (Lambda, API Gateway)
   sam deploy --guided

6. Validate deployment
   terraform output
   API endpoint health check
```

### Rollback Strategy

| Scenario              | Rollback Method                            |
| --------------------- | ------------------------------------------ |
| Failed deployment     | Re-run plan with previous state            |
| Configuration error   | `terraform destroy` + redeploy              |
| Secrets compromise    | Rotate via AWS Secrets Manager             |
| Database corruption   | Restore from backup (DynamoDB point-in-time) |

---

## 6. Infrastructure Dependencies

### Dependency Order (Critical)

```
1. IAM (roles, policies, tag-based access controls)
   ↓
2. Security (Cognito, encryption keys, secrets)
   ↓
3. Database (DynamoDB tables)
   ↓
4. Auth (Cognito user pools)
   ↓
5. Compute (Lambda, API Gateway)
   ↓
6. Monitoring (CloudWatch, logging)
```

### Cross-Environment Dependencies

* **Shared Resources (One-time setup):**
  * S3 state bucket
  * DynamoDB state lock table
  * CloudTrail for audit logging

* **Per-Environment Resources:**
  * All application resources (isolated by VPC/tags)

---

## 7. Cost Management

### Infrastructure-Level Cost Controls

| Control                       | Mechanism                         |
| ----------------------------- | --------------------------------- |
| **Resource Quotas**           | Terraform variable limits         |
| **On-Demand Provisioning**    | dev/staging destroyed after hours |
| **Reserved Capacity (prod)**  | On-demand for now, reserved later |
| **Cost Tagging**              | Environment tags for billing      |
| **Budget Alerts**             | AWS Budgets (Phase 7)             |

### Infrastructure Cost Estimate (Monthly)

| Service      | dev   | staging | prod  | Total |
| ------------ | ----- | ------- | ----- | ----- |
| DynamoDB     | $1    | $3      | $5    | $9    |
| Lambda       | $0    | $0.50   | $1    | $1.50 |
| API Gateway  | $0    | $1      | $3    | $4    |
| Cognito      | $0    | $0      | $0    | $0    |
| Secrets Mgmt | $0.50 | $0.50   | $0.50 | $1.50 |
| CloudWatch   | $0    | $0.50   | $1    | $1.50 |
| **Total**    | **$1.50**| **$5.50** | **$10.50** | **$17.50** |

*Note: Assumes free-tier eligible where possible and moderate usage*

---

## 8. Documentation & Runbooks

### Required Runbooks

1. **Initial Infrastructure Setup**
   * Prerequisites
   * Step-by-step Terraform workflow

2. **Environment Promotion**
   * Code review requirements
   * Approval gates
   * Rollback procedures

3. **State Recovery**
   * State backup restoration
   * Disaster recovery steps

4. **Cost Monitoring**
   * Cost breakdown by environment
   * Anomaly detection procedures

---

---

## 9. IAM Role Responsibility Matrix

As defined in `guide/step.md`, the IAM role responsibility identification is a core Phase 2 output. Use the dedicated IAM documentation for the detailed matrix.

**Reference:** [docs/02-iam.md](./02-iam.md)

**Summary of Defined Roles:**
1. **DeveloperRole:** Local dev/test permissions
2. **DeploymentRole:** CI/CD pipeline power-user
3. **ProductionAdminRole:** Emergency break-glass role
4. **LambdaExecutionRole:** Application runtime identity
5. **CognitoServiceRole:** Auth triggering identity

---

## Phase 2 Review Checklist

* [ ] Networking elements (CloudFront, API Gateway) defined?
* [ ] Frontend hosting infrastructure (S3) included in designs?
* [ ] Are all three environments clearly separated?
* [ ] Can infrastructure be destroyed and recreated identically?
* [ ] Are sensitive values protected from state files?
* [ ] Can state corruption be recovered from backups?
* [ ] Are cost controls in place?
* [ ] Can infrastructure changes be reviewed before application?

---

**Status:** IN PROGRESS  
**Phase Owner:** Infrastructure / DevOps Engineer  
**Last Updated:** 2025-12-14
