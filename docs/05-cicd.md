# PHASE 5 — CI/CD & Branching

This document is a step-by-step guide to stand up CI/CD and branching for this project when no repo or `.github/` folder exists yet. It assumes the architecture, infra, and app decisions defined in earlier phases.

---

## 1) Branching Strategy

**Model:** Trunk with short-lived feature branches and one staging branch.

- `main` → production source of truth; protected, release tags cut here
- `staging` → pre-prod integration; mirrors prod settings minus elevated limits
- `feature/*` → short-lived branches merged via PR into `staging`

**Environment mapping:**

| Branch    | Environment | Push | Merge PR | Notes |
| --------- | ----------- | ---- | -------- | ----- |
| main      | prod        | ❌ blocked | ✓ apply to prod (requires approval) | Production; most protected
| staging   | staging     | ❌ blocked | ✓ auto-apply to staging | Pre-prod; protected
| dev       | dev         | ❌ blocked | ✓ auto-apply to dev | Development; protected
| feature/* | dev         | ✓ allowed | → PR to dev/staging/main | Short-lived; no protection

**Protection rules:**
- All `main`, `staging`, `dev` branches require PR + status checks before merge
- Direct pushes are blocked on all three branches
- After PR merge, the `apply` job automatically runs in the target environment

---
## 3) GitHub Repository Setup (once)

1. Create branches `main`, `staging`, `dev` (all protected).
2. **Enable branch protection on all three branches:**
   - Require PR before merge (minimum 1 reviewer for `main`)
   - Require status checks (CI) to pass before merge
   - **Require branches to be up-to-date before merge**
   - **Block direct pushes** (enforce PR-only workflow)
   - Dismiss stale approvals when new commits pushed
   - Block force-push and deletions
3. Create GitHub Environments `dev`, `staging`, `prod`:
   - `dev`: no approval (auto-deploy on PR merge)
   - `staging`: optional approval
   - `prod`: **require manual approval** (blocks apply until reviewed)
4. Add repository secrets/vars:
   - `AWS_REGION`
   - `AWS_DEV_ROLE_ARN`, `AWS_STAGING_ROLE_ARN`, `AWS_PROD_ROLE_ARN`
   - `TF_STATE_BUCKET`, `PROJECT_NAME`
   - `COGNITO_USER_POOL_ID` (per env), API base URLs
5. Configure OIDC trust in AWS IAM for `token.actions.githubusercontent.com` and map to role ARNs.
1. Create branches `main` (default) and `staging`.
2. Enable branch protection:
   - Require PR, status checks, and linear history on `main` and `staging`.
   - Require 1+ reviewer for `main`; optional for `staging`.
   - Block force-push and deletions.
3. Create GitHub Environments `dev`, `staging`, `prod` with required reviewers for `prod`.
4. Add repository secrets/vars (names used in workflows below):
   - `AWS_REGION`
   - `AWS_DEV_ROLE_ARN`, `AWS_STAGING_ROLE_ARN`, `AWS_PROD_ROLE_ARN`
   - `TF_STATE_BUCKET`, `TF_STATE_TABLE`, `PROJECT_NAME`
   - `COGNITO_USER_POOL_ID` (per env) and any API base URLs as env vars.
5. Add OIDC trust in AWS IAM for `token.actions.githubusercontent.com` and map to the role ARNs above.

---
## 4) Workflow Layout
Create `.github/workflows/` with these files:

1. `backend-ci.yml` — lint, typecheck, unit tests for `backend/`
2. `backend-deploy.yml` — deploy SAM backend on push to `dev`/`staging`/`main`
3. `frontend-ci.yml` — lint, typecheck, unit tests for `frontend/`
4. `frontend-deploy.yml` — build and sync static site to S3 on push to `dev`/`staging`/`main`
5. `infra-plan-apply.yml` — Terraform plan/apply gated by environment
6. `release.yml` — cut tags/releases from `main`, post-deploy smoke

---
## 5) Backend CI (backend-ci.yml)
**Triggers:** PR to `staging` and `main`; push to `feature/*`.

```yaml
name: Backend CI
on:
  pull_request:
    branches: [staging, main]
    paths: ["backend/**"]
  push:
    branches: ["feature/**"]
    paths: ["backend/**"]
jobs:
  backend-ci:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: backend
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: lts/*
          cache: npm
          cache-dependency-path: backend/package-lock.json
      - run: npm ci
      - run: npm run lint
      - run: npm test -- --runInBand
```

---
## 5.1) Backend Deploy (backend-deploy.yml)
Deploy backend changes automatically to the corresponding environment on merge:
- Push to `dev` → deploys to dev
- Push to `staging` → deploys to staging
- Push to `main` → deploys to prod (respects GitHub Environment approvals)

```yaml
name: Backend Deploy
on:
  push:
    branches: [dev, staging, main]
    paths: ["backend/**"]
env:
  AWS_REGION: ${{ secrets.AWS_REGION }}
  PROJECT_NAME: ${{ secrets.PROJECT_NAME }}
concurrency:
  group: backend-${{ github.ref_name }}
  cancel-in-progress: true
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ github.ref_name == 'main' && 'prod' || (github.ref_name == 'staging' && 'staging' || 'dev') }}
    permissions:
      id-token: write
      contents: read
    defaults:
      run:
        working-directory: backend
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: lts/*
          cache: npm
          cache-dependency-path: backend/package-lock.json
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-region: ${{ env.AWS_REGION }}
          role-to-assume: ${{ github.ref_name == 'main' && secrets.AWS_PROD_ROLE_ARN || (github.ref_name == 'staging' && secrets.AWS_STAGING_ROLE_ARN || secrets.AWS_DEV_ROLE_ARN) }}
      - uses: aws-actions/setup-sam@v2
      - run: npm ci
      - run: npm run build
      - run: sam build
      - name: Deploy backend (SAM)
        env:
          ENV_NAME: ${{ github.ref_name == 'main' && 'prod' || (github.ref_name == 'staging' && 'staging' || 'dev') }}
        run: |
          sam deploy \
            --stack-name "${{ env.PROJECT_NAME }}-${ENV_NAME}" \
            --no-confirm-changeset \
            --no-fail-on-empty-changeset \
            --parameter-overrides Environment=${ENV_NAME}
```

Notes:
- Uses GitHub OIDC to assume `${AWS_*_ROLE_ARN}` per target branch.
- Requires `AWS_REGION` and `PROJECT_NAME` secrets.
- Respects GitHub Environment approvals (e.g., prod).

---
## 6) Frontend CI (frontend-ci.yml)
**Triggers:** PR to `staging` and `main`; push to `feature/*`.

```yaml
name: Frontend CI
on:
  pull_request:
    branches: [staging, main]
    paths: ["frontend/**"]
  push:
    branches: ["feature/**"]
    paths: ["frontend/**"]
jobs:
  frontend-ci:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: frontend
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: lts/*
          cache: npm
          cache-dependency-path: frontend/package-lock.json
      - run: npm ci
      - run: npm run lint
      - run: npm test -- --runInBand
```

---
## 6.1) Frontend Deploy (frontend-deploy.yml)
Deploy frontend automatically as a static export (Next.js `output: 'export'`) to S3:
- Push to `dev` → sync to `${PROJECT_NAME}-dev-web`
- Push to `staging` → sync to `${PROJECT_NAME}-staging-web`
- Push to `main` → sync to `${PROJECT_NAME}-prod-web` (respects approvals)

```yaml
name: Frontend Deploy
on:
  push:
    branches: [dev, staging, main]
    paths: ["frontend/**"]
env:
  AWS_REGION: ${{ secrets.AWS_REGION }}
  PROJECT_NAME: ${{ secrets.PROJECT_NAME }}
concurrency:
  group: frontend-${{ github.ref_name }}
  cancel-in-progress: true
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ github.ref_name == 'main' && 'prod' || (github.ref_name == 'staging' && 'staging' || 'dev') }}
    permissions:
      id-token: write
      contents: read
    defaults:
      run:
        working-directory: frontend
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: lts/*
          cache: npm
          cache-dependency-path: frontend/package-lock.json
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          aws-region: ${{ env.AWS_REGION }}
          role-to-assume: ${{ github.ref_name == 'main' && secrets.AWS_PROD_ROLE_ARN || (github.ref_name == 'staging' && secrets.AWS_STAGING_ROLE_ARN || secrets.AWS_DEV_ROLE_ARN) }}
      - name: Install deps
        run: npm ci
      - name: Build static site
        run: npm run build
      - name: Sync to S3
        env:
          ENV_NAME: ${{ github.ref_name == 'main' && 'prod' || (github.ref_name == 'staging' && 'staging' || 'dev') }}
        run: |
          aws s3 sync out s3://${{ env.PROJECT_NAME }}-${ENV_NAME}-web --delete
      - name: Optional CloudFront invalidation
        env:
          ENV_NAME: ${{ github.ref_name == 'main' && 'prod' || (github.ref_name == 'staging' && 'staging' || 'dev') }}
          CF_DIST_ID: ${{ github.ref_name == 'main' && secrets.CF_DIST_ID_PROD || (github.ref_name == 'staging' && secrets.CF_DIST_ID_STAGING || secrets.CF_DIST_ID_DEV) }}
        if: env.CF_DIST_ID != ''
        run: |
          aws cloudfront create-invalidation --distribution-id "$CF_DIST_ID" --paths "/*"
```

Notes:
- Buckets `${PROJECT_NAME}-{env}-web` must exist (provisioned by infra).
- Optional CloudFront distribution IDs can be provided via `CF_DIST_ID_DEV|STAGING|PROD` secrets.

---
## 7) Infra Plan/Apply (infra-plan-apply.yml)

**Triggers:**
- PR to any branch → `plan` job (review before merge)
- Push to `dev`, `staging`, `main` (after PR merge) → `apply` job (auto-deploy)
  - Push to `dev` → applies to dev
  - Push to `staging` → applies to staging  
  - Push to `main` → applies to prod (requires GitHub Environment approval)

**Note:** Direct pushes blocked by branch protection; `apply` only runs after PR merge.

```yaml
name: Infra Plan & Apply
on:
  pull_request:
    branches: [staging, main]
    paths: ["infra/**", "backend/template.yaml"]
  push:
    branches: [staging, main]
    paths: ["infra/**", "backend/template.yaml"]
env:
  AWS_REGION: ${{ secrets.AWS_REGION }}
  TF_IN_AUTOMATION: true
jobs:
  plan:
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ github.base_ref == 'main' && secrets.AWS_PROD_ROLE_ARN || secrets.AWS_STAGING_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.6
      - run: |
          cd infra/terraform/environments/${{ github.base_ref == 'main' && 'prod' || 'staging' }}
          terraform init -backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}" -backend-config="dynamodb_table=${{ secrets.TF_STATE_TABLE }}"
          terraform fmt -check
          terraform plan -out=tfplan
      - run: terraform show -json tfplan > tfplan.json
  apply:
    needs: plan
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    environment: ${{ github.ref_name == 'main' && 'prod' || 'staging' }}
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ github.ref_name == 'main' && secrets.AWS_PROD_ROLE_ARN || secrets.AWS_STAGING_ROLE_ARN }}
          aws-region: ${{ env.AWS_REGION }}
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6.6
      - run: |
          cd infra/terraform/environments/${{ github.ref_name == 'main' && 'prod' || 'staging' }}
          terraform init -backend-config="bucket=${{ secrets.TF_STATE_BUCKET }}" -backend-config="dynamodb_table=${{ secrets.TF_STATE_TABLE }}"
          terraform apply -auto-approve tfplan || terraform apply -auto-approve
```

---
## 8) Release & Deploy (release.yml)
**Triggers:** Manual dispatch or push tag `v*` on `main`.
- Builds frontend static site, packages backend with SAM, deploys to selected environment.
- After prod deploy, run minimal smoke (API `GET /notes`) using Postman or curl.

```yaml
name: Release
on:
  workflow_dispatch:
    inputs:
      env:
        description: "Environment to deploy"
        required: true
        default: prod
        type: choice
        options: [staging, prod]
  push:
    tags: ["v*"]
jobs:
  release:
    runs-on: ubuntu-latest
    environment: ${{ inputs.env || 'prod' }}
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ (inputs.env == 'prod' || startsWith(github.ref, 'refs/tags/')) && secrets.AWS_PROD_ROLE_ARN || secrets.AWS_STAGING_ROLE_ARN }}
          aws-region: ${{ secrets.AWS_REGION }}
      - name: Build backend (SAM)
        run: |
          cd backend
          npm ci
          npm run build
          sam build
      - name: Deploy backend (SAM)
        run: |
          cd backend
          sam deploy --stack-name "${{ secrets.PROJECT_NAME }}-${{ inputs.env || 'prod' }}" --no-confirm-changeset --no-fail-on-empty-changeset --parameter-overrides Environment=${{ inputs.env || 'prod' }}
      - name: Build frontend
        run: |
          cd frontend
          npm ci
          npm run build
      - name: Publish frontend artifact
        run: |
          aws s3 sync frontend/out s3://${{ secrets.PROJECT_NAME }}-${{ inputs.env || 'prod' }}-web --delete
      - name: Smoke test API
        run: |
          curl -f ${{ secrets.API_BASE_URL }}/notes || exit 1
```

Note: Regular merges auto-deploy via the dedicated backend/frontend deploy workflows. Use `release.yml` to cut versioned releases/tags and perform coordinated deploys.

---
## 9) Day-2 Operations

- **Rollback app only:** Redeploy previous tag with `release.yml` dispatch selecting the prior tag.
- **Rollback infra:** `terraform apply` with prior state (S3 version) after peer review.
- **Hotfix:** Branch from `main`, PR into `main`, cherry-pick into `staging` if needed.
- **Observability hooks:** Wire CloudWatch alarms and GitHub deploy status checks (Phase 7).

---

## 10) Verification Checklist

- Branch protections enforced on `main`/`staging`
- OIDC trust configured for GitHub Actions roles
- Secrets/vars present for all environments
- CI passes for backend and frontend
- Terraform plans visible in PRs; applies gated by environment
- Release workflow can deploy to staging, then prod after approval

---

## 11) FAQ — Separate CI and Deploy workflows?

- Separate files recommended: Keep `backend-ci.yml`/`frontend-ci.yml` (PR checks) separate from `backend-deploy.yml`/`frontend-deploy.yml` (post-merge deploys). This improves clarity, least-privilege permissions, and avoids deploy jobs appearing as required PR checks.
- Can be combined: You can place CI and deploy jobs in a single workflow with `on: [pull_request, push]` and guard deploy jobs with `if: github.event_name == 'push'`. If you do this, ensure branch protections only require the CI jobs, not the deploy ones, and set job-level permissions so CI doesn’t request AWS creds.
- Recommendation: Use separate workflows unless you have a strong reason to unify, especially when prod uses GitHub Environment approvals.
