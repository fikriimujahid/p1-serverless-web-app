# Complete GitHub Setup Guide
**Repository · Actions · Environments · Secure CI/CD**

## 📋 Prerequisites
1. GitHub account with admin access to the repository.
2. `gh` (GitHub CLI) installed and authenticated: `gh auth login`.
3. Repo already exists (or create it): `gh repo create <owner>/<repo>`.
4. AWS bootstrap outputs available (see `guide/03-1-terraform-setup.md`): OIDC provider ARN and role ARNs created by Terraform.
5. Project docs present: `docs/02-cicd.md` and `docs/02-release.md` (used as policy references).

---

## 1. Repository and Branch Protection

Purpose: prevent direct pushes to `main`, enforce PR reviews and passing checks.

1. Open your repo in GitHub and go to **Settings → Branches → Branch protection rules**.
2. Add a rule for `main`:
   - Require pull request reviews before merging (include code owners if used).
   - Require status checks to pass (list CI checks you plan to run).
   - Require linear history (optional) and disallow force pushes.
   - Restrict who can push (only CI bot or admins via workflows).
3. Add a rule for `develop`:
   - Require PR reviews and passing CI checks.
   - Allow maintainers to merge if appropriate.

Optional CLI (example):

```bash
# Protect branch using the REST API (replace OWNER/REPO and BRANCH)
gh api --method PUT /repos/OWNER/REPO/branches/main/protection -f required_status_checks='{"strict":true,"contexts":[]}' -f enforce_admins=true -f required_pull_request_reviews='{"required_approving_review_count":2}'
```

Notes:
- The UI is simpler for one-off configuration; use the API/automation for repeatable setups.

---

## 2. Create GitHub Environments (dev / staging / prod)

Purpose: provide manual gates, environment-level secrets, and required reviewers for deploys.

1. In the repo go to **Settings → Environments** and create environments: `dev`, `staging`, `prod`.
2. For each environment configure protection rules:
   - `dev`: optional reviewers, short wait time.
   - `staging`: require 1-2 reviewers; require a manual reviewer before deployment.
   - `prod`: require at least 1 senior reviewer and optionally require deployment branches (`main` only).
3. (Optional) Add required deployment branches under each environment to restrict which branches can trigger deploys.

CLI hint (create environment):

```bash
# Create environment via the API (idempotent)
gh api --method PUT /repos/OWNER/REPO/actions/environments/dev
gh api --method PUT /repos/OWNER/REPO/actions/environments/staging
gh api --method PUT /repos/OWNER/REPO/actions/environments/prod
```

---

## 3. Store Secrets and Environment Secrets

Purpose: securely store AWS credentials, backend keys, and other secrets used by workflows.

Recommended secrets:

- `AWS_ROLE_TO_ASSUME_DEV` — ARN of CI deploy role for `dev` (or use OIDC and no long-lived keys)
- `AWS_ROLE_TO_ASSUME_PROD` — ARN of CI deploy role for `prod`
- `TERRAFORM_BACKEND_KEY_DEV` / `TERRAFORM_BACKEND_KEY_PROD` — backend key names if using S3 remote state
- `NOTIFICATION_WEBHOOK` — optional

1. Add repository-level secrets for generic values:

```bash
echo "${VALUE}" | gh secret set NOTIFICATION_WEBHOOK --repo OWNER/REPO
```

2. Add environment-level secrets (recommended for `prod`):

```bash
echo "${AWS_ROLE_ARN}" | gh secret set AWS_ROLE_TO_ASSUME_PROD --repo OWNER/REPO --env prod
```

Notes:
- Prefer GitHub Actions OIDC (no long-lived AWS keys). If using OIDC, you still may store role ARNs as plain strings and authorize the `token.actions.githubusercontent.com` OIDC provider in AWS (see `guide/03-1-terraform-setup.md`).

---

## 4. Configure GitHub Actions OIDC (short-lived creds)

Purpose: avoid storing AWS long-lived keys in GitHub by using GitHub Actions OIDC to assume AWS roles.

High-level steps:

1. Ensure the AWS OIDC provider is created (Terraform `bootstrap` module from `guide/03-1-terraform-setup.md` creates `aws_iam_openid_connect_provider`).
2. In AWS, create IAM roles for CI with a trust policy that allows `token.actions.githubusercontent.com` to assume the role for the repo and specific workflows/branches.
3. Expose the role ARNs as repository or environment secrets (string only). Example role names are produced by Terraform outputs: `cicd_runner_role_arn`, `terraform_prod_role_arn`.

Example IAM trust policy conditions (conceptual):

```json
// Condition example to bind to a specific repository
{"StringLike": {"token.actions.githubusercontent.com:sub": "repo:OWNER/REPO:*"}}
```

Refer to `guide/03-1-terraform-setup.md` for automated role and OIDC provider creation and saved Terraform outputs.

---

## 5. Add Workflows (CI + Deploy + Release)

Purpose: implement the logical pipeline stages from `docs/02-cicd.md` (validate, test, build, package, deploy, smoke).

Recommended workflow files (examples):

- `.github/workflows/ci.yml` — runs on `pull_request` (Validate, Unit Test, Build)
- `.github/workflows/dev-deploy.yml` — runs on `push` to `develop` (auto deploy to `dev` environment)
- `.github/workflows/promote.yml` — manual workflow to promote a build to `staging`/`prod` with environment protection
- `.github/workflows/release.yml` — tags and publishes release notes after successful `prod` deploy

Minimal `ci.yml` skeleton:

```yaml
name: CI
on: [pull_request]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install Node
        uses: actions/setup-node@v4
        with: node-version: 18
      - name: Lint
        run: npm run lint
      - name: Test
        run: npm test
```

Minimal deploy step using OIDC to assume role (conceptual):

```yaml
- name: Configure AWS credentials
  uses: aws-actions/configure-aws-credentials@v2
  with:
    role-to-assume: ${{ secrets.AWS_ROLE_TO_ASSUME_PROD }}
    aws-region: us-east-1
```

Notes:
- Use `environment` key in the deploy job to bind the job to GitHub environment protections (e.g., reviewers):

```yaml
deploy:
  environment: prod
  needs: build
  runs-on: ubuntu-latest
  steps: ...
```

---

## 6. Release/Semver and Tagging

Purpose: automate tagging and release-note publication after successful `prod` deploy.

1. After `prod` deploy and post-deploy smoke tests pass, tag the commit: `vMAJOR.MINOR.PATCH`.

```bash
git tag v1.2.3
git push origin v1.2.3
# or via gh
gh release create v1.2.3 --notes "Release notes summary"
```

2. Ensure release workflow attaches pipeline run ID and PR links in release notes (see `docs/02-release.md`).

---

## 7. Protecting Production and Approvals

1. Configure environment `prod` to require manual approvals by specified reviewers in **Settings → Environments → prod**.
2. Set `branch protection` so only the `promote` workflow or `main` merges can trigger production deploys.

---

## 8. Post-setup Validation

1. Create a feature branch and open a PR — confirm `ci.yml` runs and required checks appear on PR.
2. Merge to `develop` and confirm `dev-deploy.yml` auto-deploys to the `dev` environment (check Actions run and AWS resources if applicable).
3. Use `promote.yml` to run a manual promotion to `staging`/`prod` and confirm environment reviewers are enforced.

Commands to check Actions runs:

```bash
# List recent workflow runs
gh run list --repo OWNER/REPO

# View a specific run
gh run view RUN_ID --repo OWNER/REPO --log
```

---

## 9. Troubleshooting & Common Pitfalls

- If CI cannot assume role, check OIDC provider thumbprint and IAM trust relationship.
- If secrets appear missing in Actions, ensure they are set at the correct scope (repo vs environment).
- If branch protection blocks CI, add the workflow status checks to the protection rule.

---

## 10. Playbook / Next Steps

- Document workflow filenames under `.github/workflows/` and link to `docs/02-cicd.md` for pipeline contract.
- Use `guide/03-1-terraform-setup.md` to re-run bootstrap and re-create IAM/OIDC tooling as needed.
- Optional: create prepared GitHub Actions templates and store them under `.github/` for reuse.

---

**Quick Checklist**

- [ ] `main` and `develop` branch protections configured
- [ ] `dev`, `staging`, `prod` environments created with protection rules
- [ ] Secrets populated (repo + environment)
- [ ] OIDC-based IAM roles created in AWS and role ARNs saved as secrets
- [ ] CI workflows added and status checks registered
- [ ] Release workflow configured to tag and publish notes

---

References:

- CI/CD design: [docs/02-cicd.md](docs/02-cicd.md)
- Release & rollback: [docs/02-release.md](docs/02-release.md)
- Terraform bootstrap: `guide/03-1-terraform-setup.md`
