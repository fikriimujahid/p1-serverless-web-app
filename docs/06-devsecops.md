# 06 — DevSecOps

This guide implements comprehensive security automation in CI/CD using open-source tools for dependency scanning, IaC security, SAST, DAST, and secrets detection.

---

## Security Scanning Overview

| Scan Type           | Tool              | Target                    | When       |
| ------------------- | ----------------- | ------------------------- | ---------- |
| Secrets Scanning    | Gitleaks          | All files                 | CI (PR)    |
| Dependency Scanning | npm audit + Snyk  | package.json/package-lock | CI (PR)    |
| IaC Security        | Checkov + TFSec   | Terraform files           | CI (PR)    |
| SAST                | Semgrep           | Source code               | CI (PR)    |
| DAST                | OWASP ZAP         | Running application       | Post-deploy|

---

## 1) Secrets Scanning with Gitleaks

Goal: Detect hardcoded secrets in code and git history.

### GitHub Actions Workflow

Create `.github/workflows/security-secrets.yml`:

```yaml
name: Secrets Scan

on:
  pull_request:
    branches: [dev, main]
  push:
    branches: [dev, main]

jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Full history for comprehensive scan

      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}  # Optional: for enterprise features
```

### Local Testing (Optional)

```powershell
# Install Gitleaks (Windows)
# Download from https://github.com/gitleaks/gitleaks/releases
# Or use: choco install gitleaks

# Run scan
gitleaks detect --source . --verbose
```

---

## 2) Dependency Scanning

Goal: Identify vulnerable dependencies in backend and frontend.

### GitHub Actions Workflow

Create `.github/workflows/security-dependencies.yml`:

```yaml
name: Dependency Scan

on:
  pull_request:
    branches: [dev, main]
  push:
    branches: [dev, main]
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday

jobs:
  backend-dependencies:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: backend
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-node@v4
        with:
          node-version: lts/*
      
      - name: Install dependencies
        run: npm ci
      
      - name: npm audit
        run: npm audit --audit-level=moderate
        continue-on-error: true
      
      - name: Snyk Security Scan
        uses: snyk/actions/node@master
        continue-on-error: true
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          command: test
          args: --severity-threshold=high --file=backend/package.json

  frontend-dependencies:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: frontend
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-node@v4
        with:
          node-version: lts/*
      
      - name: Install dependencies
        run: npm ci
      
      - name: npm audit
        run: npm audit --audit-level=moderate
        continue-on-error: true
      
      - name: Snyk Security Scan
        uses: snyk/actions/node@master
        continue-on-error: true
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          command: test
          args: --severity-threshold=high --file=frontend/package.json
```

---

## 3) IaC Security Scanning

Goal: Detect security misconfigurations in Terraform code.

### GitHub Actions Workflow

Create `.github/workflows/security-iac.yml`:

```yaml
name: IaC Security Scan

on:
  pull_request:
    branches: [dev, main]
    paths: ['infra/**']
  push:
    branches: [dev, main]
    paths: ['infra/**']

jobs:
  checkov:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Checkov on Terraform
        uses: bridgecrewio/checkov-action@master
        with:
          directory: infra/terraform
          framework: terraform
          output_format: cli
          soft_fail: false
          skip_check: CKV_AWS_18,CKV_AWS_144  # Adjust based on your needs
      
      - name: Run Checkov on SAM Template
        uses: bridgecrewio/checkov-action@master
        with:
          file: backend/template.yaml
          framework: cloudformation
          output_format: cli
          soft_fail: false

  tfsec:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run tfsec
        uses: aquasecurity/tfsec-action@v1.0.3
        with:
          working_directory: infra/terraform
          soft_fail: false
          
  terrascan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Terrascan
        uses: tenable/terrascan-action@main
        with:
          iac_type: terraform
          iac_dir: infra/terraform
          policy_type: aws
          only_warn: false
```

### Local Testing

```powershell
# Install Checkov
pip install checkov

# Scan Terraform
cd infra/terraform
checkov -d . --framework terraform
cd ../..

# Scan SAM template
checkov -f backend/template.yaml --framework cloudformation

# Install tfsec (Windows)
# Download from https://github.com/aquasecurity/tfsec/releases
# Or use: choco install tfsec

# Run tfsec
tfsec .
```

---

## 4) SAST (Static Application Security Testing)

Goal: Detect security vulnerabilities in source code.

### GitHub Actions Workflow

Create `.github/workflows/security-sast.yml`:

```yaml
name: SAST

on:
  pull_request:
    branches: [dev, main]
  push:
    branches: [dev, main]

jobs:
  semgrep:
    runs-on: ubuntu-latest
    container:
      image: returntocorp/semgrep
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Semgrep
        run: |
          semgrep scan --config=auto \
            --error \
            --severity ERROR \
            --severity WARNING \
            --exclude "node_modules" \
            --exclude "dist" \
            --exclude "build" \
            --exclude ".next" \
            --json > semgrep-results.json
      
      - name: Upload results
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: semgrep-results
          path: semgrep-results.json

  eslint-security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-node@v4
        with:
          node-version: lts/*
      
      - name: Install ESLint security plugins
        run: |
          npm install -g eslint eslint-plugin-security eslint-plugin-no-secrets
      
      - name: Backend security scan
        run: |
          cd backend
          npm ci
          npx eslint . --ext .ts,.js --plugin security --plugin no-secrets
        continue-on-error: true
      
      - name: Frontend security scan
        run: |
          cd frontend
          npm ci
          npx eslint . --ext .ts,.tsx,.js,.jsx --plugin security
        continue-on-error: true
```

### Local Testing

```powershell
# Install Semgrep
pip install semgrep

# Run scan
semgrep scan --config=auto

# Or use Docker
docker run --rm -v "${PWD}:/src" returntocorp/semgrep semgrep scan --config=auto
```

---

## 5) DAST (Dynamic Application Security Testing)

Goal: Test running application for security vulnerabilities.

### GitHub Actions Workflow

Create `.github/workflows/security-dast.yml`:

```yaml
name: DAST

on:
  workflow_dispatch:
    inputs:
      target_url:
        description: 'Target URL for DAST scan'
        required: true
        default: 'https://dev.yourapp.com'
  schedule:
    - cron: '0 2 * * 1'  # Weekly on Monday at 2 AM

jobs:
  zap-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: OWASP ZAP Baseline Scan
        uses: zaproxy/action-baseline@v0.12.0
        with:
          target: ${{ github.event.inputs.target_url || 'https://dev.yourapp.com' }}
          rules_file_name: '.zap/rules.tsv'
          cmd_options: '-a'
          
      - name: Upload ZAP Report
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: zap-report
          path: report_html.html

  zap-full-scan:
    runs-on: ubuntu-latest
    if: github.event_name == 'schedule'
    steps:
      - uses: actions/checkout@v4
      
      - name: OWASP ZAP Full Scan
        uses: zaproxy/action-full-scan@v0.10.0
        with:
          target: ${{ github.event.inputs.target_url || 'https://dev.yourapp.com' }}
          rules_file_name: '.zap/rules.tsv'
          cmd_options: '-a'
          
      - name: Upload ZAP Report
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: zap-full-report
          path: report_html.html
```

### ZAP Rules Configuration

Create `.zap/rules.tsv` at repo root:

```tsv
10021	WARN	(X-Content-Type-Options Header Missing)
10023	WARN	(Information Disclosure - Debug Error Messages)
10027	WARN	(Information Disclosure - Suspicious Comments)
10096	WARN	(Timestamp Disclosure)
10098	WARN	(Cross-Domain Misconfiguration)
```

### Local DAST Testing

```powershell
# Run OWASP ZAP in Docker
docker run -t owasp/zap2docker-stable zap-baseline.py -t https://yourapp.com -r zap-report.html

# Or install ZAP desktop for GUI testing
# Download from: https://www.zaproxy.org/download/
```

---

## 6) CI: IAM Role Assumption via OIDC (GitHub Actions)

Goal: Deploy securely without long-lived AWS keys by assuming a role through OIDC.

### Steps

1. Prerequisites
   - Configure AWS OIDC provider and a trust policy for your GitHub org/repo
   - Create a deploy role with least-privilege permissions for the pipeline
   - See setup reference in [docs/05-oidc-setup.md](05-oidc-setup.md)

2. Minimal workflow snippet (example)

```yaml
name: deploy-backend
on:
  push:
    branches: ["main"]

jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/github-actions-deploy
          aws-region: us-east-1

      - name: Validate Infra
        run: |
          cd infra/terraform/environments/dev
          terraform init -backend-config=backend.hcl
          terraform validate

      - name: Deploy Backend (example)
        run: |
          cd backend
          npm ci
          npm run sam:deploy
```

3. Tighten trust policy
   - Restrict to your repository and branches via `sub`/`aud` conditions
   - Use environment-specific roles (e.g., `dev`, `prod`) with distinct permissions

4. Verification
   - Remove static AWS secrets from repo and CI settings
   - Confirm short-lived credentials are minted during workflow runs

### Deliverable

- A secure CI pipeline that assumes AWS roles via OIDC, with least privilege and no long-lived credentials.

---

---

## Integration Recommendations

### 1. Add Security Gates to Existing Workflows

Update existing CI workflows to include security checks:

**backend-ci.yml** - Add:
```yaml
- name: Run Semgrep
  run: npx semgrep scan --config=auto --error
  continue-on-error: true
```

**infra-plan-apply.yml** - Add before apply:
```yaml
- name: Run Checkov
  run: |
    pip install checkov
    checkov -d infra/terraform --framework terraform
```

### 2. Configure Branch Protection Rules

In GitHub repository settings, require these checks to pass:
- ✓ Secrets Scan (gitleaks)
- ✓ Dependency Scan (npm audit)
- ✓ IaC Security (checkov/tfsec)
- ✓ SAST (semgrep)

### 3. Security Monitoring Dashboard

Use GitHub Security tab to:
- Review Dependabot alerts
- Track security advisories
- Monitor code scanning results
- Manage secret scanning alerts

### 4. Configure Snyk (Optional)

For enhanced dependency scanning:
1. Sign up at https://snyk.io (free for open source)
2. Add `SNYK_TOKEN` to GitHub secrets
3. Snyk will automatically create PRs for vulnerable dependencies

---

## Quick Setup Commands

```powershell
# Create .github/workflows directory
New-Item -ItemType Directory -Force -Path .github\workflows

# Navigate to project root
cd c:\DEMOP\p1-serverless-web-app

# Create security workflow files (copy content from above sections)
# - security-secrets.yml
# - security-dependencies.yml
# - security-iac.yml
# - security-sast.yml
# - security-dast.yml

# Create ZAP configuration
New-Item -ItemType Directory -Force -Path .zap
# Add rules.tsv content

# Commit and push
git add .github/workflows .zap
git commit -m "feat: add comprehensive security scanning"
git push
```

---

## Summary

This DevSecOps implementation provides:

1. **Shift-Left Security**: Catch issues early in PRs
2. **Comprehensive Coverage**: Secrets, dependencies, IaC, code, and runtime
3. **Automation**: All scans run automatically in CI/CD
4. **Open Source**: No licensing costs, community-supported tools
5. **Compliance**: Supports SOC2, PCI-DSS, and GDPR requirements

All security scans integrate seamlessly with GitHub's security features and provide actionable feedback in pull requests.
