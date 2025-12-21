# Security Reports

This directory contains the results of local security scans.

## Quick Start

Run all security scans and generate a combined report:

```powershell
cd C:\DEMOP\p1-serverless-web-app
.\run-all-scans.ps1
```

This will:
1. Run all security scans (Gitleaks, npm audit, Checkov on Terraform & SAM, TFSec, Semgrep)
2. Generate JSON reports for each scan
3. Create a combined HTML report: `security-report.html`
4. Automatically open the report in your browser

## Generated Files

After running scans, you'll find:

- `security-report.html` - **Combined HTML report** (start here!)
- `gitleaks-report.json` - Secrets scanning results
- `backend-npm-audit.json` - Backend dependency vulnerabilities
- `frontend-npm-audit.json` - Frontend dependency vulnerabilities
- `terraform/results_json.json` - Checkov Terraform IaC security results
- `sam/results_json.json` - Checkov SAM template security results
- `tfsec-report.json` - TFSec Terraform security results
- `semgrep-report.json` - SAST code analysis results

## Documentation

For detailed instructions, see:
- **Complete Guide:** [guide/06-local-security-scans.md](../guide/06-local-security-scans.md)
- **Quick Reference:** [.github/SECURITY.md](../.github/SECURITY.md)
- **DevSecOps Overview:** [docs/06-devsecops.md](../docs/06-devsecops.md)

## Note

This directory is git-ignored to prevent committing scan results.
Scan results should be reviewed locally and not committed to version control.
