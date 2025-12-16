# PHASE 3 — IAM Security & Access Control

**Purpose of this document**
This document defines the Identity and Access Management (IAM) strategy, including role definitions, permission boundaries, and risk assessment. It provides the foundational security model that will be implemented in Phase 3.

---

## Executive Summary

The IAM security model follows **least-privilege** principles with clearly defined roles for different users and services. All access is explicitly granted through IAM policies, and logging/auditing is centralized for accountability.

---

## 1. IAM Core Principles

### Foundational Rules

1. **Least Privilege:** Grant only minimum required permissions
2. **Separation of Duties:** Different roles for development, deployment, and operations
3. **Auditability:** All actions logged and attributable to an identity
4. **Automation:** Use temporary credentials via IAM roles, avoid long-lived access keys
5. **Protection:** Prod environment access more restricted than dev

### Permission Model

* **Human Users:** IAM users with console access (dev/admin only)
* **Services:** IAM roles with temporary credentials (Lambda, deployment pipelines)
* **Temporary Access:** Time-bounded and purpose-limited

---

## 2. IAM Role Responsibility Matrix

### Role Definitions & Permissions

#### Role 1: DeveloperRole

| Attribute         | Value                                                   |
| ----------------- | ------------------------------------------------------- |
| **Used By**       | Development engineers (dev, staging environments only) |
| **Purpose**       | Local development, testing, infrastructure changes      |
| **Environment**   | dev, staging                                            |
| **Duration**      | Active during working hours, MFA required               |
| **Permissions**   | See Permission Table below                              |
| **Risk Level**    | MEDIUM                                                  |

**Permissions Granted:**

| Service    | Action                           | Resource             | Condition            |
| ---------- | -------------------------------- | -------------------- | -------------------- |
| Lambda     | `lambda:InvokeFunction`          | `arn:aws:lambda:*:*:function:*-dev` | None |
| Lambda     | `lambda:UpdateFunctionCode`      | `arn:aws:lambda:*:*:function:*-dev` | None |
| DynamoDB   | `dynamodb:*`                    | `arn:aws:dynamodb:*:*:table/*-dev` | None |
| API Gateway| `apigateway:*`                   | `arn:aws:apigateway:*::/restapis/*-dev` | None |
| Cognito    | `cognito-idp:*`                  | `arn:aws:cognito-idp:*:*:userpool/*-dev*` | None |
| S3         | `s3:GetObject`, `s3:PutObject`   | `arn:aws:s3:::*-dev/*` | None |
| CloudWatch | `logs:CreateLogGroup`, `logs:PutLogEvents` | `arn:aws:logs:*:*:log-group:/aws/lambda/*-dev*` | None |
| IAM        | `iam:PassRole`                   | `arn:aws:iam::*:role/lambda-execution-role-dev` | `sts:ExternalId` required |

**Explicit Denies:**

* `iam:*` (except PassRole for specific roles)
* Any prod environment resources

---

#### Role 2: DeploymentRole

| Attribute         | Value                                                |
| ----------------- | ----------------------------------------------------- |
| **Used By**       | CI/CD pipeline (GitHub Actions / GitLab CI)          |
| **Purpose**       | Automated infrastructure and application deployments |
| **Environment**   | All (dev, staging, prod)                             |
| **Duration**      | Short-lived temporary credentials (15 min sessions)  |
| **Permissions**   | See Permission Table below                           |
| **Risk Level**    | HIGH (Most powerful, most audited)                   |

**Permissions Granted:**

| Service      | Action                                 | Resource                    | Condition           |
| ------------ | -------------------------------------- | --------------------------- | ------------------- |
| Terraform    | All S3 + DynamoDB for state management | State backend resources     | Source IP (CI only) |
| CloudFormation | `cloudformation:*`                     | `arn:aws:cloudformation:*:*:stack/*` | None |
| Lambda       | `lambda:*`                            | All Lambda functions        | None |
| API Gateway  | `apigateway:*`                         | All API Gateway resources   | None |
| DynamoDB     | `dynamodb:*`                          | All DynamoDB tables         | None |
| Cognito      | `cognito-idp:*`                       | All Cognito user pools      | None |
| S3           | `s3:*`                                | Deployment artifact buckets | None |
| IAM          | `iam:PassRole`, `iam:GetRole`          | Lambda execution roles      | None |
| Secrets      | `secretsmanager:GetSecretValue`       | All deployment secrets      | None |
| CloudWatch   | `logs:*`, `cloudwatch:*`               | All log groups and metrics  | None |
| SNS/SQS      | Minimal (if queuing used)              | Restricted to app resources | None |

**Explicit Denies:**

* `iam:DeleteRole`, `iam:PutUserPolicy`
* `iam:CreateAccessKey`, `iam:CreateUser`

**Condition Constraints:**

* Source IP restricted to CI/CD runner
* Time-based constraints (no access outside business hours for staging/prod)

---

#### Role 3: ProductionAdminRole

| Attribute         | Value                                          |
| ----------------- | ---------------------------------------------- |
| **Used By**       | Senior/on-call engineers (emergency response) |
| **Purpose**       | Production incident response and recovery     |
| **Environment**   | prod only                                      |
| **Duration**      | Requires manual activation, 2-hour limit       |
| **Permissions**   | See Permission Table below                     |
| **Risk Level**    | CRITICAL (Requires approval and MFA)          |

**Permissions Granted:**

| Service      | Action                                 | Resource              | Condition        |
| ------------ | -------------------------------------- | --------------------- | ---------------- |
| DynamoDB     | `dynamodb:*`                          | All prod tables       | Requires MFA     |
| Lambda       | `lambda:InvokeFunction`, `lambda:UpdateFunctionCode` | Prod functions | Requires MFA     |
| Secrets      | `secretsmanager:GetSecretValue`       | Prod secrets          | Requires MFA     |
| CloudWatch   | `logs:*`, `cloudwatch:*`               | Prod logs and metrics | None |
| SNS          | `sns:Publish`                         | Incident response SNS | None |

**Explicit Denies:**

* `iam:*` (except temporary credential elevation)
* `s3:DeleteBucket`, `dynamodb:DeleteTable`
* `sts:AssumeRole` without MFA

**Activation Process:**

```
1. Engineer requests access (via Slack bot or ticketing)
2. Approval required from engineering manager
3. 30-minute activation window
4. 2-hour session limit
5. All actions logged to CloudTrail
```

---

#### Role 4: LambdaExecutionRole

| Attribute         | Value                                          |
| ----------------- | ---------------------------------------------- |
| **Used By**       | AWS Lambda functions                           |
| **Purpose**       | Runtime permissions for Lambda code            |
| **Environment**   | All (dev, staging, prod)                       |
| **Duration**      | Assumed by Lambda service automatically         |
| **Permissions**   | See Permission Table below                     |
| **Risk Level**    | MEDIUM (Limited to app resources)              |

**Permissions Granted:**

| Service      | Action                                 | Resource                 | Condition |
| ------------ | -------------------------------------- | ------------------------ | --------- |
| DynamoDB     | `dynamodb:GetItem`, `dynamodb:PutItem`, `dynamodb:Query`, `dynamodb:UpdateItem` | App tables | None |
| Secrets      | `secretsmanager:GetSecretValue`       | App secrets              | None |
| CloudWatch   | `logs:CreateLogGroup`, `logs:CreateLogStream`, `logs:PutLogEvents` | Lambda log groups | None |
| S3           | `s3:GetObject`                        | Frontend build artifacts | None |

**Explicit Denies:**

* `iam:*`
* `dynamodb:DeleteTable`
* `s3:DeleteObject` (read-only to S3)

**Trust Policy:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

---

#### Role 5: CognitoServiceRole

| Attribute         | Value                                          |
| ----------------- | ---------------------------------------------- |
| **Used By**       | Amazon Cognito (for post-auth triggers)       |
| **Purpose**       | Lambda invocations during auth flow            |
| **Environment**   | All (dev, staging, prod)                       |
| **Duration**      | Assumed by Cognito service automatically        |
| **Permissions**   | Minimal (see Permission Table below)            |
| **Risk Level**    | LOW (Single-purpose)                           |

**Permissions Granted:**

| Service | Action                | Resource              | Condition |
| ------- | --------------------- | --------------------- | --------- |
| Lambda  | `lambda:InvokeFunction` | Cognito trigger Lambda | None |

**Trust Policy:**

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "cognito-idp.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
```

---

## 3. Risk Assessment Matrix

### Risk Factors by Role

| Role                    | Blast Radius | Damage Potential | Monitoring | Overall Risk |
| ----------------------- | ------------ | ---------------- | ---------- | ------------ |
| **DeveloperRole**       | dev/staging  | Medium           | Standard   | MEDIUM       |
| **DeploymentRole**      | All envs     | High (automated) | High       | HIGH         |
| **ProductionAdminRole** | prod only    | Critical         | Critical   | CRITICAL     |
| **LambdaExecutionRole** | App data     | Medium           | Standard   | MEDIUM       |
| **CognitoServiceRole**  | Auth only    | Low              | Standard   | LOW          |

### Risk Mitigation Strategies

| Risk                        | Mitigation                                      |
| --------------------------- | ----------------------------------------------- |
| Credential compromise       | Temporary credentials via STS AssumeRole        |
| Privilege escalation        | Explicit denies for sensitive actions            |
| Production data leakage     | MFA required for prod admin access              |
| Audit trail tampering       | CloudTrail configured with S3 protection        |
| Accidental resource deletion | Explicit denies for destructive actions          |
| Deployment errors           | Code review + plan approval before apply         |

---

## 4. Service-to-Service Authorization

### Cross-Service Permissions

#### Lambda → DynamoDB

```
Permission: dynamodb:GetItem, PutItem, Query, UpdateItem
Target:    Application tables only (name-based wildcard)
Example:   arn:aws:dynamodb:*:*:table/notes-app-*
```

#### Lambda → Secrets Manager

```
Permission: secretsmanager:GetSecretValue
Target:    Application secrets only
Example:   arn:aws:secretsmanager:*:*:secret:notes-app/*
```

#### API Gateway → Lambda

```
Trust Policy:
Principal: apigateway.amazonaws.com
Action:    lambda:InvokeFunction
Resource:  All app Lambda functions
```

#### Cognito → Lambda

```
Trust Policy:
Principal: cognito-idp.amazonaws.com
Action:    lambda:InvokeFunction
Resource:  Cognito trigger Lambda only
```

---

## 5. Credential Management

### Human Users (Developers)

| Aspect             | Implementation                                 |
| ------------------ | ---------------------------------------------- |
| **Console Access** | IAM console via AWS SSO (recommended)           |
| **Programmatic**   | Temporary credentials via `aws sts assume-role` |
| **MFA**            | Required for all console access                 |
| **Key Rotation**   | Every 90 days (if using access keys)            |
| **Audit**          | CloudTrail logs all console/API activity        |

### Service Credentials (CI/CD Pipeline)

| Aspect             | Implementation                                 |
| ------------------ | ---------------------------------------------- |
| **Type**           | OpenID Connect (OIDC) token exchange (GitHub Actions) |
| **Duration**       | 15-minute temporary credentials                |
| **Refresh**        | Automatic, no manual key management             |
| **Audit**          | CloudTrail logs all deployments                 |
| **Revocation**     | Automatic at session end                        |

### Secrets Storage

| Secret Type        | Storage Location           | Access Control                 |
| ------------------ | -------------------------- | ------------------------------ |
| DB passwords       | AWS Secrets Manager        | IAM role-based access          |
| API keys           | AWS Parameter Store        | Encrypted, KMS key-protected   |
| JWT signing keys   | AWS Secrets Manager        | Limited to auth Lambda         |
| OAuth credentials  | AWS Secrets Manager        | Limited to frontend build      |

---

## 6. Audit & Compliance

### Logging Strategy

| Event                    | Logged To       | Retention | Alert   |
| ------------------------ | --------------- | --------- | ------- |
| Console login            | CloudTrail      | 90 days   | Yes     |
| API calls                | CloudTrail      | 90 days   | Yes     |
| Deployment (apply/destroy) | CloudTrail + Application logs | 90 days | Yes |
| Secrets access           | CloudTrail      | 90 days   | Yes     |
| Failed auth attempts     | CloudWatch      | 30 days   | Yes     |

### Audit Reports

**Monthly reviews:**
* Active IAM roles and users
* Unused credentials (>60 days)
* Permissions changes
* Failed access attempts
* Production access logs

---

## 7. Access Request & Approval Workflow

### New Access Request Process

```
Developer → IAM Access Request Form
    ↓
Manager Approval (2 business days)
    ↓
Infrastructure Team Implementation
    ↓
Notification & Testing Confirmation
    ↓
Access Granted
```

### Offboarding Process

```
Engineer notifies (resignation/transfer)
    ↓
Disable all access keys
    ↓
Remove from all IAM groups
    ↓
Revoke any active sessions
    ↓
Audit any leftover access
    ↓
Confirm completion
```

---

## 8. Phase 2 Implementation Checklist

* [ ] All 5 IAM roles defined and tested
* [ ] Trust policies configured for service-to-service access
* [ ] CloudTrail enabled and protecting audit logs
* [ ] MFA enforced for console and prod access
* [ ] Secrets Manager configured with encryption
* [ ] Access request workflow documented
* [ ] Emergency access procedures tested
* [ ] All roles reviewed for least-privilege

---

## 9. Known Risks & Future Improvements

### Current Limitations

* Single AWS account (production and dev in same account)
  * *Mitigation:* Tag-based IAM policies enforce environment isolation
  * *Future:* Multi-account strategy with cross-account roles for enterprise scale

* Manual approval for emergency access
  * *Mitigation:* Time-limited sessions (2 hours max)
  * *Future:* Automated approval based on incident tickets

* No resource-level encryption key policies
  * *Mitigation:* AWS managed keys used
  * *Future:* Customer-managed KMS keys with key rotation

---

## Phase 2 Review Checklist

* Are all user roles clearly defined with specific responsibilities?
* Do permissions follow least-privilege principles?
* Can data be accessed without going through appropriate roles?
* Are audit trails protected and non-tamperable?
* Can access be revoked quickly if needed?
* Are risks clearly identified and mitigated?

---

**Status:** IN PROGRESS  
**Phase Owner:** Security / Infrastructure Engineer  
**Last Updated:** 2025-12-14
