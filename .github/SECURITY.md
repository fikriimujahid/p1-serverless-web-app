# Security Scanning

This project implements comprehensive DevSecOps practices using open-source security tools.

## Automated Security Scans (CI/CD)

All security scans run automatically on pull requests and pushes to `dev` and `main` branches.

### Active Workflows

| Workflow                 | File                              | Tools Used                    | Frequency       |
| ------------------------ | --------------------------------- | ----------------------------- | --------------- |
| Secrets Scanning         | `security-secrets.yml`            | Gitleaks                      | Every PR/Push   |
| Dependency Scanning      | `security-dependencies.yml`       | npm audit, Snyk               | Every PR/Push + Weekly |
| IaC Security             | `security-iac.yml`                | Checkov, TFSec, Terrascan     | PR/Push (infra changes) |
| SAST                     | `security-sast.yml`               | Semgrep, ESLint-security      | Every PR/Push   |
| DAST                     | `security-dast.yml`               | OWASP ZAP                     | Weekly + Manual |

## Local Testing (Optional)

> **📘 Complete Guide Available:** For detailed step-by-step instructions on running local security scans from scratch and generating combined reports, see [Local Security Scanning Guide](../guide/06-local-security-scans.md)

### Quick Start - Run All Scans

```powershell
# Clone the repo and navigate to project root
cd C:\DEMOP\p1-serverless-web-app

# Run all security scans and generate report (one command!)
.\run-all-scans.ps1

# View the combined HTML report (opens automatically)
```

### Prerequisites

```powershell
# Install Python (for Checkov, Semgrep)
# Download from https://www.python.org/downloads/

# Install Node.js LTS
# Download from https://nodejs.org/

# Install Chocolatey (Windows package manager)
# https://chocolatey.org/install

# Install all security tools
choco install gitleaks tfsec -y
pip install checkov semgrep
```

### Quick Individual Scans

```powershell
# Secrets Scan with Gitleaks
choco install gitleaks
gitleaks detect --source . --verbose

# Dependency Scan
cd backend
npm audit --audit-level=moderate
cd ../frontend
npm audit --audit-level=moderate

# IaC Scan with Checkov
pip install checkov
checkov -d infra/terraform --framework terraform

# IaC Scan with TFSec
choco install tfsec
cd infra/terraform
tfsec .

# SAST with Semgrep
pip install semgrep
semgrep scan --config=auto

# DAST with OWASP ZAP (requires Docker)
docker pull owasp/zap2docker-stable
docker run -t owasp/zap2docker-stable zap-baseline.py -t https://yourapp.com
```

## Configuration

### Snyk Setup (Optional but Recommended)

1. Sign up at https://snyk.io (free for open-source projects)
2. Get your API token from Account Settings
3. Add `SNYK_TOKEN` to GitHub repository secrets
4. Snyk will automatically scan dependencies and create PRs for vulnerabilities

### Customizing Scans

#### Skip Specific Checkov Rules

Edit [security-iac.yml](.github/workflows/security-iac.yml):
```yaml
skip_check: CKV_AWS_18,CKV_AWS_144,CKV_AWS_XX
```

#### Configure ZAP Rules

Edit [.zap/rules.tsv](.zap/rules.tsv) to adjust warning levels:
- `IGNORE` - Skip the rule
- `WARN` - Report but don't fail
- `FAIL` - Fail the scan if found

#### Adjust npm audit Severity

Edit [security-dependencies.yml](.github/workflows/security-dependencies.yml):
```yaml
npm audit --audit-level=high  # Change to: low, moderate, high, critical
```

## Security Reports

All security scan results are uploaded as artifacts in GitHub Actions:
1. Go to Actions tab in GitHub
2. Select a workflow run
3. Download artifacts at the bottom of the page

## Branch Protection

Recommended branch protection rules for `main` and `dev`:

1. Require pull request reviews
2. Require status checks to pass:
   - ✓ gitleaks (Secrets Scan)
   - ✓ backend-dependencies (Dependency Scan)
   - ✓ frontend-dependencies (Dependency Scan)
   - ✓ checkov (IaC Security)
   - ✓ tfsec (IaC Security)
   - ✓ semgrep (SAST)

## Troubleshooting

### False Positives in Secrets Scan

If Gitleaks detects false positives, you can create a `.gitleaksignore` file:
```
# Format: <file>:<line>:<commit>
backend/tests/fixtures/sample-data.ts:12:1234567890abcdef
```

### npm audit Failures

If vulnerabilities have no fix available, you can:
1. Add exceptions temporarily (use sparingly)
2. Track in security advisory
3. Plan migration to alternative packages

### IaC Scan Failures

Review the specific CKV check codes in Checkov output:
- Some checks may not apply to your architecture
- Document exceptions in [06-devsecops.md](../docs/06-devsecops.md)
- Use `skip_check` parameter judiciously with justification

## Additional Resources

- [Full DevSecOps Documentation](../docs/06-devsecops.md)
- [Gitleaks Documentation](https://github.com/gitleaks/gitleaks)
- [Snyk Documentation](https://docs.snyk.io/)
- [Checkov Documentation](https://www.checkov.io/documentation.html)
- [Semgrep Documentation](https://semgrep.dev/docs/)
- [OWASP ZAP Documentation](https://www.zaproxy.org/docs/)
