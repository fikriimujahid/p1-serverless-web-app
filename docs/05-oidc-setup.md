# GitHub OIDC Setup for AWS IAM (Phase 5)

This guide fixes the error "Not authorized to perform sts:AssumeRoleWithWebIdentity" by correctly configuring AWS IAM trust for GitHub Actions OIDC and wiring secrets/environments.

---

## 1) Overview

- GitHub Actions issues an OIDC token from `token.actions.githubusercontent.com`.
- AWS IAM roles must trust that OIDC provider and allow `sts:AssumeRoleWithWebIdentity` with scoped conditions (repo and branch).
- Workflows then call `aws-actions/configure-aws-credentials@v4` to assume the role.

---

## 2) Create/Verify OIDC Provider in AWS

In AWS IAM (console):
- Federated identity providers → Add provider → Type: OpenID Connect
- Provider URL: `https://token.actions.githubusercontent.com`
- Audience: `sts.amazonaws.com`

If using Terraform (recommended one-time in bootstrap):

```hcl
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["ffffffffffffffffffffffffffffffffffffffff"] # AWS-managed; see docs
}
```

---

## 3) IAM Role Trust Policy (per environment)

Attach this trust relationship to each deployment role (dev/staging/prod). Replace `ACCOUNT_ID`, `ORG`, and `REPO`.

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": [
            "repo:ORG/REPO:ref:refs/heads/dev",
            "repo:ORG/REPO:ref:refs/heads/staging",
            "repo:ORG/REPO:ref:refs/heads/main"
          ]
        }
      }
    }
  ]
}
```

Notes:
- Scope to branches used by your workflow triggers (dev/staging/main). Add patterns for tags if needed: `repo:ORG/REPO:ref:refs/tags/v*`.
- For Pull Request runs, GitHub emits `sub: repo:ORG/REPO:pull_request`. Include this if your plan job needs AWS access:

```json
{
  "StringLike": {
    "token.actions.githubusercontent.com:sub": [
      "repo:ORG/REPO:ref:refs/heads/dev",
      "repo:ORG/REPO:ref:refs/heads/staging",
      "repo:ORG/REPO:ref:refs/heads/main",
      "repo:ORG/REPO:pull_request"
    ]
  }
}
```

- Optional hardening: restrict to a specific workflow file using `job_workflow_ref`:

```json
{
  "StringLike": {
    "token.actions.githubusercontent.com:job_workflow_ref": "ORG/REPO/.github/workflows/infra-plan-apply.yml@*"
  }
}
```

Terraform example for a role (dev):

```hcl
resource "aws_iam_role" "deploy_dev" {
  name = "DeploymentRoleDev"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = "arn:aws:iam::${var.account_id}:oidc-provider/token.actions.githubusercontent.com"
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/dev",
            "repo:${var.github_org}/${var.github_repo}:pull_request"
          ]
        }
      }
    }]
  })
}
```

---

## 4) Attach Permissions to Roles

Each role (`DeploymentRoleDev`, `DeploymentRoleStaging`, `DeploymentRoleProd`) needs least-privilege policies for:
- Terraform state bucket/table access (S3/DynamoDB)
- Creating/updating/deleting infra resources in its environment
- SAM deploy (CloudFormation, Lambda, API Gateway)

Keep prod stricter (e.g., require manual approval in GitHub Environment).

---

## 5) GitHub Setup

- Repository secrets:
  - `AWS_REGION`, `AWS_DEV_ROLE_ARN`, `AWS_STAGING_ROLE_ARN`, `AWS_PROD_ROLE_ARN`
  - `TF_STATE_BUCKET`, `TF_STATE_TABLE`
- Environments: `dev`, `staging`, `prod` (optionally gate `prod` with reviewers)
- Workflow (`.github/workflows/infra-plan-apply.yml`) must include:
  - `permissions: { id-token: write, contents: read }`
  - `aws-actions/configure-aws-credentials@v4` with `role-to-assume`, `audience: sts.amazonaws.com`

---

## 6) Validate

1. Push to `dev` changing `infra/**` → workflow should assume `AWS_DEV_ROLE_ARN` and run `terraform` in `infra/terraform/environments/dev`.
2. Open a PR into `staging` → plan runs using `AWS_STAGING_ROLE_ARN`.
3. Merge to `staging` → apply runs in staging.
4. Push to `main` → apply runs in prod (ensure environment requires approval).

If errors persist:
- Check IAM role trust `Principal.Federated` ARN and `audience` value.
- Inspect workflow run’s OIDC token via job logs (enable debug): `ACTIONS_STEP_DEBUG=true`.
- Confirm `github.ref_name` and `github.base_ref` match your branch names used in trust conditions.
