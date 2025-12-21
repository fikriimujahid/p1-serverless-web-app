# Local Security Scanning Guide

This guide provides step-by-step instructions to run all security scans locally on Windows and generate a combined security report.

---

## Table of Contents

1. [Prerequisites & Installation](#1-prerequisites--installation)
2. [Running Individual Scans](#2-running-individual-scans)
3. [Generating Combined Report](#3-generating-combined-report)
4. [Interpreting Results](#4-interpreting-results)
5. [Troubleshooting](#5-troubleshooting)

---

## 1. Prerequisites & Installation

### Step 1.1: Install Core Tools

#### Python 3.11+

```powershell
# Check if Python is installed
python --version

# If not installed, download from https://www.python.org/downloads/
# During installation, check "Add Python to PATH"
```

#### Node.js LTS

```powershell
# Check if Node.js is installed
node --version

# If not installed, download from https://nodejs.org/
```

#### Chocolatey (Windows Package Manager)

```powershell
# Install Chocolatey (run as Administrator)
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# Verify installation
choco --version
```

### Step 1.2: Install Security Tools

Open PowerShell as Administrator and run:

```powershell
# Navigate to project root
cd C:\DEMOP\p1-serverless-web-app

# Install Python-based tools
python -m pip install --upgrade pip
pip install checkov semgrep detect-secrets jq

# Install Gitleaks
choco install gitleaks -y

# Install TFSec
choco install tfsec -y

# Install Docker Desktop (for OWASP ZAP)
choco install docker-desktop -y
# Note: You'll need to restart after Docker installation

# Install jq for JSON processing
choco install jq -y

# Verify installations
gitleaks --version
tfsec --version
checkov --version
semgrep --version
docker --version
```

### Step 1.3: Install Project Dependencies

```powershell
# Backend dependencies
cd backend
npm ci
cd ..

# Frontend dependencies
cd frontend
npm ci
cd ..
```

---

## 2. Running Individual Scans

### Step 2.1: Secrets Scanning with Gitleaks

```powershell
# Navigate to project root
cd C:\DEMOP\p1-serverless-web-app

# Create reports directory
New-Item -ItemType Directory -Force -Path security-reports

# Run Gitleaks scan
Write-Output "`n=== Running Secrets Scan with Gitleaks ===`n"
gitleaks detect --source . --report-path security-reports/gitleaks-report.json --report-format json --verbose

# Check results
if ($LASTEXITCODE -eq 0) {
    Write-Output "✓ No secrets detected"
} else {
    Write-Output "✗ Secrets detected - review security-reports/gitleaks-report.json"
}
```

**What it checks:**
- Hardcoded API keys, passwords, tokens
- AWS credentials
- Private keys
- Database connection strings

### Step 2.2: Dependency Scanning with npm audit

```powershell
Write-Output "`n=== Running Dependency Scan ===`n"

# Backend dependencies
Write-Output "Scanning backend dependencies..."
cd backend
npm audit --json > ../security-reports/backend-npm-audit.json
npm audit --audit-level=moderate
cd ..

# Frontend dependencies
Write-Output "Scanning frontend dependencies..."
cd frontend
npm audit --json > ../security-reports/frontend-npm-audit.json
npm audit --audit-level=moderate
cd ..
```

**What it checks:**
- Known vulnerabilities in npm packages
- Outdated dependencies with security patches
- Transitive dependency vulnerabilities

### Step 2.3: IaC Security Scanning

#### Checkov

```powershell
Write-Output "`n=== Running IaC Scan with Checkov ===`n"

# Scan Terraform configurations
Write-Output "Scanning Terraform files..."
checkov -d infra/terraform `
    --framework terraform `
    --output json `
    --output-file-path security-reports/terraform `
    --soft-fail

# Scan SAM/CloudFormation templates
Write-Output "Scanning SAM templates..."
checkov -f backend/template.yaml `
    --framework cloudformation `
    --output json `
    --output-file-path security-reports/sam `
    --soft-fail

# Generate human-readable report
Write-Output "Combined IaC scan results:"
checkov -d infra/terraform `
    --framework terraform `
    --output cli
checkov -f backend/template.yaml `
    --framework cloudformation `
    --output cli
```

**What it checks:**
- IAM overly permissive policies
- Unencrypted resources
- Public access configurations
- Missing security groups
- Logging and monitoring gaps
- Lambda function security (from SAM template)
- API Gateway configurations
- DynamoDB table encryption and access

#### TFSec

```powershell
Write-Output "`n=== Running IaC Scan with TFSec ===`n"

cd infra/terraform

# JSON output for combined report
tfsec . --format json --out ../../security-reports/tfsec-report.json --soft-fail

# Detailed console output
tfsec . --format default

cd ../..

# Note: TFSec doesn't directly support SAM/CloudFormation templates
# Use Checkov for SAM template scanning (covered above)
```

**What it checks:**
- AWS security best practices
- Encryption settings
- Network security configurations
- Resource exposure

### Step 2.4: SAST with Semgrep

```powershell
Write-Output "`n=== Running SAST with Semgrep ===`n"

# Scan with auto-config (recommended rules)
semgrep scan --config=auto `
    --json `
    --output security-reports/semgrep-report.json `
    --exclude "node_modules" `
    --exclude "dist" `
    --exclude "build" `
    --exclude ".next" `
    --exclude ".terraform" `
    --severity ERROR `
    --severity WARNING

# Human-readable output
semgrep scan --config=auto `
    --exclude "node_modules" `
    --exclude "dist" `
    --exclude "build" `
    --exclude ".next" `
    --exclude ".terraform"
```

**What it checks:**
- SQL injection vulnerabilities
- XSS (Cross-Site Scripting)
- Command injection
- Path traversal
- Insecure cryptography
- Authentication issues

### Step 2.5: ESLint Security Scan

```powershell
Write-Output "`n=== Running ESLint Security Scan ===`n"

# Backend
cd backend
npm install --save-dev eslint-plugin-security eslint-plugin-no-secrets
npx eslint . --ext .ts,.js --format json --output-file ../security-reports/backend-eslint.json
npx eslint . --ext .ts,.js
cd ..

# Frontend
cd frontend
npm install --save-dev eslint-plugin-security
npx eslint . --ext .ts,.tsx,.js,.jsx --format json --output-file ../security-reports/frontend-eslint.json
npx eslint . --ext .ts,.tsx,.js,.jsx
cd ..
```

### Step 2.6: DAST with OWASP ZAP (Optional - Requires Running App)

**Note:** DAST requires your application to be running. Follow these steps:

```powershell
# First, deploy your app locally or use dev environment
# For example, if using dev environment:
$TARGET_URL = "https://your-dev-app.com"

Write-Output "`n=== Running DAST with OWASP ZAP ===`n"

# Pull ZAP Docker image
docker pull owasp/zap2docker-stable

# Run baseline scan
docker run -v ${PWD}:/zap/wrk:rw `
    -t owasp/zap2docker-stable `
    zap-baseline.py `
    -t $TARGET_URL `
    -J security-reports/zap-report.json `
    -r security-reports/zap-report.html

Write-Output "ZAP scan complete. Report saved to security-reports/"
```

**What it checks:**
- SQL injection (runtime)
- XSS vulnerabilities
- CSRF issues
- Security headers
- Cookie security
- SSL/TLS configuration

---

## 3. Generating Combined Report

### Step 3.1: Create Report Generation Script

Create a PowerShell script to combine all scan results:

```powershell
# Create the script
@'
# Combined Security Report Generator
# Usage: .\generate-security-report.ps1

$reportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$projectRoot = "C:\DEMOP\p1-serverless-web-app"
$reportsDir = "$projectRoot\security-reports"

# Initialize report
$htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Security Scan Report - $reportDate</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; border-left: 4px solid #3498db; padding-left: 10px; }
        .summary { background: #ecf0f1; padding: 15px; border-radius: 5px; margin: 20px 0; }
        .success { color: #27ae60; font-weight: bold; }
        .warning { color: #f39c12; font-weight: bold; }
        .danger { color: #e74c3c; font-weight: bold; }
        .info { color: #3498db; font-weight: bold; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th { background: #34495e; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background: #f8f9fa; }
        .metric { display: inline-block; margin: 10px 20px 10px 0; padding: 10px 15px; background: #fff; border-radius: 5px; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
        .metric-value { font-size: 24px; font-weight: bold; color: #3498db; }
        .metric-label { font-size: 12px; color: #7f8c8d; text-transform: uppercase; }
        pre { background: #2c3e50; color: #ecf0f1; padding: 15px; border-radius: 5px; overflow-x: auto; }
        .timestamp { color: #7f8c8d; font-size: 14px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔒 Security Scan Report</h1>
        <p class="timestamp">Generated: $reportDate</p>
        <div class="summary">
            <h2>Executive Summary</h2>
"@

# Function to safely parse JSON
function Get-SafeJsonContent {
    param($filePath)
    if (Test-Path $filePath) {
        try {
            return Get-Content $filePath -Raw | ConvertFrom-Json
        } catch {
            Write-Warning "Could not parse $filePath"
            return $null
        }
    }
    return $null
}

# Function to count issues
function Count-Issues {
    param($data, $type)
    if ($null -eq $data) { return 0 }
    
    switch ($type) {
        "gitleaks" { return ($data | Measure-Object).Count }
        "npm" { 
            if ($data.vulnerabilities) {
                return ($data.vulnerabilities.PSObject.Properties | Measure-Object).Count
            }
            return 0
        }
        "checkov" { 
            if ($data.results.failed_checks) {
                return ($data.results.failed_checks | Measure-Object).Count
            }
            return 0
        }
        "semgrep" { 
            if ($data.results) {
                return ($data.results | Measure-Object).Count
            }
            return 0
        }
    }
    return 0
}

# Parse scan results
$gitleaksData = Get-SafeJsonContent "$reportsDir\gitleaks-report.json"
$backendNpmData = Get-SafeJsonContent "$reportsDir\backend-npm-audit.json"
$frontendNpmData = Get-SafeJsonContent "$reportsDir\frontend-npm-audit.json"
$checkovData = Get-SafeJsonContent "$reportsDir\results_json.json"
$tfsecData = Get-SafeJsonContent "$reportsDir\tfsec-report.json"
$semgrepData = Get-SafeJsonContent "$reportsDir\semgrep-report.json"

# Count issues
$secretsCount = Count-Issues $gitleaksData "gitleaks"
$backendVulns = Count-Issues $backendNpmData "npm"
$frontendVulns = Count-Issues $frontendNpmData "npm"
$checkovFailed = Count-Issues $checkovData "checkov"
$tfsecIssues = if ($tfsecData.results) { ($tfsecData.results | Measure-Object).Count } else { 0 }
$semgrepIssues = Count-Issues $semgrepData "semgrep"

$totalIssues = $secretsCount + $backendVulns + $frontendVulns + $checkovFailed + $tfsecIssues + $semgrepIssues

# Add metrics
$htmlReport += @"
            <div class="metric">
                <div class="metric-value">$totalIssues</div>
                <div class="metric-label">Total Issues</div>
            </div>
            <div class="metric">
                <div class="metric-value">$secretsCount</div>
                <div class="metric-label">Secrets</div>
            </div>
            <div class="metric">
                <div class="metric-value">$($backendVulns + $frontendVulns)</div>
                <div class="metric-label">Vulnerabilities</div>
            </div>
            <div class="metric">
                <div class="metric-value">$($checkovFailed + $tfsecIssues)</div>
                <div class="metric-label">IaC Issues</div>
            </div>
            <div class="metric">
                <div class="metric-value">$semgrepIssues</div>
                <div class="metric-label">Code Issues</div>
            </div>
        </div>

        <h2>📋 Detailed Results</h2>
"@

# Secrets Scanning Results
$htmlReport += @"
        <h3>1. Secrets Scanning (Gitleaks)</h3>
        <table>
            <tr><th>Status</th><td>$(if($secretsCount -eq 0){"<span class='success'>✓ PASS</span>"}else{"<span class='danger'>✗ FAIL - $secretsCount secret(s) found</span>"})</td></tr>
            <tr><th>Report</th><td><a href='gitleaks-report.json'>gitleaks-report.json</a></td></tr>
        </table>
"@

# Dependency Scanning Results
$htmlReport += @"
        <h3>2. Dependency Scanning (npm audit)</h3>
        <table>
            <tr>
                <th>Component</th>
                <th>Critical</th>
                <th>High</th>
                <th>Moderate</th>
                <th>Low</th>
                <th>Total</th>
            </tr>
            <tr>
                <td>Backend</td>
                <td>$(if($backendNpmData.metadata.vulnerabilities.critical){$backendNpmData.metadata.vulnerabilities.critical}else{0})</td>
                <td>$(if($backendNpmData.metadata.vulnerabilities.high){$backendNpmData.metadata.vulnerabilities.high}else{0})</td>
                <td>$(if($backendNpmData.metadata.vulnerabilities.moderate){$backendNpmData.metadata.vulnerabilities.moderate}else{0})</td>
                <td>$(if($backendNpmData.metadata.vulnerabilities.low){$backendNpmData.metadata.vulnerabilities.low}else{0})</td>
                <td>$backendVulns</td>
            </tr>
            <tr>
                <td>Frontend</td>
                <td>$(if($frontendNpmData.metadata.vulnerabilities.critical){$frontendNpmData.metadata.vulnerabilities.critical}else{0})</td>
                <td>$(if($frontendNpmData.metadata.vulnerabilities.high){$frontendNpmData.metadata.vulnerabilities.high}else{0})</td>
                <td>$(if($frontendNpmData.metadata.vulnerabilities.moderate){$frontendNpmData.metadata.vulnerabilities.moderate}else{0})</td>
                <td>$(if($frontendNpmData.metadata.vulnerabilities.low){$frontendNpmData.metadata.vulnerabilities.low}else{0})</td>
                <td>$frontendVulns</td>
            </tr>
        </table>
"@

# IaC Scanning Results
$htmlReport += @"
        <h3>3. Infrastructure as Code Security</h3>
        <table>
            <tr>
                <th>Tool</th>
                <th>Passed</th>
                <th>Failed</th>
                <th>Skipped</th>
                <th>Status</th>
            </tr>
            <tr>
                <td>Checkov</td>
                <td>$(if($checkovData.summary.passed){$checkovData.summary.passed}else{0})</td>
                <td>$(if($checkovData.summary.failed){$checkovData.summary.failed}else{0})</td>
                <td>$(if($checkovData.summary.skipped){$checkovData.summary.skipped}else{0})</td>
                <td>$(if($checkovFailed -eq 0){"<span class='success'>✓ PASS</span>"}else{"<span class='warning'>⚠ $checkovFailed issue(s)</span>"})</td>
            </tr>
            <tr>
                <td>TFSec</td>
                <td>-</td>
                <td>$tfsecIssues</td>
                <td>-</td>
                <td>$(if($tfsecIssues -eq 0){"<span class='success'>✓ PASS</span>"}else{"<span class='warning'>⚠ $tfsecIssues issue(s)</span>"})</td>
            </tr>
        </table>
"@

# SAST Results
$htmlReport += @"
        <h3>4. Static Application Security Testing (Semgrep)</h3>
        <table>
            <tr><th>Total Issues</th><td>$semgrepIssues</td></tr>
            <tr><th>Status</th><td>$(if($semgrepIssues -eq 0){"<span class='success'>✓ PASS</span>"}else{"<span class='warning'>⚠ Review required</span>"})</td></tr>
            <tr><th>Report</th><td><a href='semgrep-report.json'>semgrep-report.json</a></td></tr>
        </table>
"@

# Recommendations
$htmlReport += @"
        <h2>💡 Recommendations</h2>
        <ul>
"@

if ($secretsCount -gt 0) {
    $htmlReport += "<li><span class='danger'>CRITICAL:</span> Remove hardcoded secrets immediately and rotate compromised credentials.</li>"
}
if ($backendVulns -gt 0 -or $frontendVulns -gt 0) {
    $htmlReport += "<li><span class='warning'>HIGH:</span> Update vulnerable dependencies using npm audit fix or manual updates.</li>"
}
if ($checkovFailed -gt 0 -or $tfsecIssues -gt 0) {
    $htmlReport += "<li><span class='warning'>MEDIUM:</span> Review IaC security issues and implement recommended fixes.</li>"
}
if ($semgrepIssues -gt 0) {
    $htmlReport += "<li><span class='info'>MEDIUM:</span> Review code security issues identified by Semgrep.</li>"
}
if ($totalIssues -eq 0) {
    $htmlReport += "<li><span class='success'>✓</span> No security issues detected. Continue monitoring regularly.</li>"
}

$htmlReport += @"
        </ul>

        <h2>📁 Raw Reports</h2>
        <ul>
            <li><a href='gitleaks-report.json'>Gitleaks JSON Report</a></li>
            <li><a href='backend-npm-audit.json'>Backend npm Audit</a></li>
            <li><a href='frontend-npm-audit.json'>Frontend npm Audit</a></li>
            <li><a href='results_json.json'>Checkov Report</a></li>
            <li><a href='tfsec-report.json'>TFSec Report</a></li>
            <li><a href='semgrep-report.json'>Semgrep Report</a></li>
        </ul>

        <hr>
        <p style='text-align: center; color: #7f8c8d; font-size: 12px;'>
            Generated by Security Scan Automation | $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        </p>
    </div>
</body>
</html>
"@

# Save HTML report
$htmlReport | Out-File -FilePath "$reportsDir\security-report.html" -Encoding UTF8

Write-Host "`n✓ Combined security report generated: security-reports\security-report.html" -ForegroundColor Green
Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "  Total Issues: $totalIssues" -ForegroundColor $(if($totalIssues -eq 0){"Green"}else{"Yellow"})
Write-Host "  Secrets: $secretsCount" -ForegroundColor $(if($secretsCount -eq 0){"Green"}else{"Red"})
Write-Host "  Vulnerabilities: $($backendVulns + $frontendVulns)" -ForegroundColor $(if(($backendVulns + $frontendVulns) -eq 0){"Green"}else{"Yellow"})
Write-Host "  IaC Issues: $($checkovFailed + $tfsecIssues)" -ForegroundColor $(if(($checkovFailed + $tfsecIssues) -eq 0){"Green"}else{"Yellow"})
Write-Host "  Code Issues: $semgrepIssues" -ForegroundColor $(if($semgrepIssues -eq 0){"Green"}else{"Yellow"})

# Open report in browser
Start-Process "$reportsDir\security-report.html"
'@ | Out-File -FilePath generate-security-report.ps1 -Encoding UTF8

Write-Output "✓ Report generation script created: generate-security-report.ps1"
```

### Step 3.2: Run All Scans and Generate Report

Create a master script to run everything:

```powershell
# Save this as run-all-scans.ps1
@'
# Master Security Scan Script
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║     Security Scanning Suite - Starting All Scans          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

$ErrorActionPreference = "Continue"
$projectRoot = "C:\DEMOP\p1-serverless-web-app"
Set-Location $projectRoot

# Create reports directory
New-Item -ItemType Directory -Force -Path security-reports | Out-Null

# 1. Secrets Scan
Write-Host "[1/5] Running Secrets Scan (Gitleaks)..." -ForegroundColor Yellow
gitleaks detect --source . --report-path security-reports/gitleaks-report.json --report-format json --no-banner 2>$null
if ($LASTEXITCODE -eq 0) {
    Write-Host "  ✓ Secrets scan complete - No issues found" -ForegroundColor Green
} else {
    Write-Host "  ⚠ Secrets scan complete - Issues detected" -ForegroundColor Red
}

# 2. Dependency Scan
Write-Host "[2/5] Running Dependency Scan (npm audit)..." -ForegroundColor Yellow
Set-Location backend
npm audit --json 2>$null | Out-File -FilePath ../security-reports/backend-npm-audit.json
Set-Location ../frontend
npm audit --json 2>$null | Out-File -FilePath ../security-reports/frontend-npm-audit.json
Set-Location ..
Write-Host "  ✓ Dependency scan complete" -ForegroundColor Green

# 3. IaC Security
Write-Host "[3/5] Running IaC Security Scans..." -ForegroundColor Yellow
Write-Host "  - Checkov..." -ForegroundColor Gray
checkov -d infra/terraform --framework terraform --output json --output-file-path security-reports --quiet --soft-fail 2>$null
Write-Host "  - TFSec..." -ForegroundColor Gray
Set-Location infra/terraform
tfsec . --format json --out ../../security-reports/tfsec-report.json --soft-fail 2>$null
Set-Location ../..
Write-Host "  ✓ IaC security scans complete" -ForegroundColor Green

# 4. SAST
Write-Host "[4/5] Running SAST (Semgrep)..." -ForegroundColor Yellow
semgrep scan --config=auto --json --output security-reports/semgrep-report.json --exclude "node_modules" --exclude "dist" --exclude "build" --exclude ".next" --exclude ".terraform" --quiet 2>$null
Write-Host "  ✓ SAST scan complete" -ForegroundColor Green

# 5. Generate Report
Write-Host "[5/5] Generating Combined Report..." -ForegroundColor Yellow
.\generate-security-report.ps1
Write-Host ""
Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║          All Security Scans Complete!                     ║" -ForegroundColor Green
Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
'@ | Out-File -FilePath run-all-scans.ps1 -Encoding UTF8

Write-Output "✓ Master scan script created: run-all-scans.ps1"
```

### Step 3.3: Execute Complete Scan

```powershell
# Make sure you're in the project root
cd C:\DEMOP\p1-serverless-web-app

# Run all scans and generate report
.\run-all-scans.ps1

# The HTML report will open automatically in your browser
# Location: security-reports/security-report.html
```

---

## 4. Interpreting Results

### Understanding Severity Levels

| Severity | Action Required | Timeline |
|----------|-----------------|----------|
| **CRITICAL** | Immediate fix required | Within 24 hours |
| **HIGH** | Fix before next release | Within 1 week |
| **MEDIUM** | Plan fix in sprint | Within 1 month |
| **LOW** | Track and fix when possible | Backlog |
| **INFO** | Informational only | No action |

### Common Findings and Fixes

#### Secrets Detected
```powershell
# 1. Remove from code
# 2. Add to .gitignore: .env, .env.local, *.pem, *.key
# 3. Use environment variables
# 4. Rotate compromised credentials immediately
# 5. Add to AWS Secrets Manager or Parameter Store
```

#### Vulnerable Dependencies
```powershell
# Automatic fix (when available)
npm audit fix

# Force fix (may introduce breaking changes)
npm audit fix --force

# Manual update
npm update <package-name>
npm install <package-name>@latest
```

#### IaC Issues - Common Fixes

**S3 Bucket Public Access:**
```hcl
resource "aws_s3_bucket_public_access_block" "example" {
  bucket = aws_s3_bucket.example.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

**Missing Encryption:**
```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "example" {
  bucket = aws_s3_bucket.example.id
  
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

#### Code Security Issues

**SQL Injection:**
```typescript
// Bad
const query = `SELECT * FROM users WHERE id = ${userId}`;

// Good - Use parameterized queries
const query = "SELECT * FROM users WHERE id = ?";
db.query(query, [userId]);
```

**XSS Prevention:**
```typescript
// Bad
element.innerHTML = userInput;

// Good - Use textContent or sanitize
element.textContent = userInput;
// Or use a sanitization library
```

---

## 5. Troubleshooting

### Issue: Gitleaks Not Found

```powershell
# Verify installation
gitleaks version

# If not found, reinstall
choco install gitleaks -y --force

# Add to PATH manually
$env:Path += ";C:\ProgramData\chocolatey\bin"
```

### Issue: Python Module Not Found

```powershell
# Verify Python installation
python --version
pip --version

# Reinstall module
pip uninstall checkov
pip install checkov

# Check if added to PATH
$env:Path += ";C:\Users\<YourUsername>\AppData\Local\Programs\Python\Python311\Scripts"
```

### Issue: Docker Not Running (ZAP Scan)

```powershell
# Check Docker status
docker --version
docker ps

# Start Docker Desktop
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Wait for Docker to start (30 seconds)
Start-Sleep -Seconds 30

# Verify
docker run hello-world
```

### Issue: npm audit Showing Too Many Issues

```powershell
# Check only production dependencies
npm audit --production

# Filter by severity
npm audit --audit-level=high

# Generate detailed report
npm audit --json > audit-detailed.json
```

### Issue: Semgrep Running Slowly

```powershell
# Exclude more directories
semgrep scan --config=auto `
    --exclude "node_modules" `
    --exclude "dist" `
    --exclude "build" `
    --exclude ".next" `
    --exclude ".terraform" `
    --exclude "coverage" `
    --exclude ".aws-sam"

# Or scan specific directories only
semgrep scan --config=auto backend/src frontend/src
```

### Issue: Report Generation Fails

```powershell
# Check if all JSON files exist
Get-ChildItem security-reports\*.json

# Validate JSON files
Get-Content security-reports\gitleaks-report.json | ConvertFrom-Json

# Re-run individual scans if needed
gitleaks detect --source . --report-path security-reports/gitleaks-report.json --report-format json
```

### Issue: Permission Denied Errors

```powershell
# Run PowerShell as Administrator
# Right-click PowerShell → Run as Administrator

# Or fix execution policy
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## Quick Reference Commands

```powershell
# Full scan suite (all-in-one)
cd C:\DEMOP\p1-serverless-web-app
.\run-all-scans.ps1

# Individual scans
gitleaks detect --source . --verbose                                    # Secrets
npm audit                                                                # Dependencies
checkov -d infra/terraform --framework terraform                        # IaC (Checkov)
tfsec infra/terraform                                                   # IaC (TFSec)
semgrep scan --config=auto                                              # SAST

# Generate report only (after running scans)
.\generate-security-report.ps1

# View report
Start-Process security-reports\security-report.html

# Clean up old reports
Remove-Item security-reports\* -Force
```

---

## Scheduled Scanning (Optional)

Set up Windows Task Scheduler to run scans automatically:

```powershell
# Create scheduled task (weekly scan on Sunday 2 AM)
$action = New-ScheduledTaskAction -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\DEMOP\p1-serverless-web-app\run-all-scans.ps1"

$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At 2am

$principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive

Register-ScheduledTask -TaskName "SecurityScanWeekly" `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Description "Weekly security scan for P1 Serverless Web App"

Write-Output "✓ Weekly security scan scheduled for Sunday at 2 AM"
```

---

## Next Steps

1. ✅ Run initial security scan
2. ✅ Review and remediate critical issues
3. ✅ Document false positives and exceptions
4. ✅ Integrate scans into CI/CD pipeline
5. ✅ Set up automated scanning schedule
6. ✅ Configure alerts for critical findings
7. ✅ Train team on security best practices

---

## Additional Resources

- [Security Scanning Quick Reference](../.github/SECURITY.md)
- [DevSecOps Documentation](../docs/06-devsecops.md)
- [Gitleaks Configuration](https://github.com/gitleaks/gitleaks#configuration)
- [Checkov Policies](https://www.checkov.io/5.Policy%20Index/all.html)
- [Semgrep Rules](https://semgrep.dev/explore)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
