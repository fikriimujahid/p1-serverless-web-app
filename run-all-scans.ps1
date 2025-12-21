# Master Security Scan Script
# Runs all security scans and generates a combined report
# Usage: .\run-all-scans.ps1

$ErrorActionPreference = "Continue"
$projectRoot = $PSScriptRoot
$zapTarget = "https://p1.fikri.dev/"  # Hardcoded ZAP target (override here if needed)
Set-Location $projectRoot

Write-Host ""
Write-Host "Security Scanning Suite - Starting All Scans" -ForegroundColor Cyan
Write-Host ("Date: {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -ForegroundColor Cyan
Write-Host ""

# Create reports directory
Write-Host "Preparing environment..." -ForegroundColor Gray
New-Item -ItemType Directory -Force -Path security-reports | Out-Null
Write-Host "  Reports directory ready" -ForegroundColor Green
Write-Host ""

# 1. Secrets Scan
Write-Host "[1/6] Running Secrets Scan (Gitleaks)..." -ForegroundColor Yellow
try {
    gitleaks detect --source . --report-path security-reports/gitleaks-report.json --report-format json --no-banner 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  Secrets scan complete - No issues found" -ForegroundColor Green
    } else {
        Write-Host "  Secrets scan complete - Issues detected" -ForegroundColor Red
    }
} catch {
    Write-Host "  Gitleaks scan failed: $_" -ForegroundColor Red
}
Write-Host ""

# 2. Dependency Scan
Write-Host "[2/6] Running Dependency Scan (npm audit)..." -ForegroundColor Yellow
try {
    Write-Host "  Scanning backend dependencies..." -ForegroundColor Gray
    Push-Location backend
    npm audit --json 2>$null | Out-File -FilePath ../security-reports/backend-npm-audit.json -Encoding UTF8
    Pop-Location

    Write-Host "  Scanning frontend dependencies..." -ForegroundColor Gray
    Push-Location frontend
    npm audit --json 2>$null | Out-File -FilePath ../security-reports/frontend-npm-audit.json -Encoding UTF8
    Pop-Location

    Write-Host "  Dependency scan complete" -ForegroundColor Green
} catch {
    Write-Host "  Dependency scan failed: $_" -ForegroundColor Red
}
Write-Host ""

# 3. IaC Security
Write-Host "[3/6] Running IaC Security Scans..." -ForegroundColor Yellow
try {
    Write-Host "  Running Checkov on Terraform..." -ForegroundColor Gray
    checkov -d infra/terraform --framework terraform --output json --output-file-path security-reports/terraform --quiet --soft-fail 2>&1 | Out-Null
    Write-Host "  Terraform scan complete" -ForegroundColor Green

    Write-Host "  Running Checkov on SAM template..." -ForegroundColor Gray
    checkov -f backend/template.yaml --framework cloudformation --output json --output-file-path security-reports/sam --quiet --soft-fail 2>&1 | Out-Null
    Write-Host "  SAM template scan complete" -ForegroundColor Green

    Write-Host "  Running TFSec on Terraform..." -ForegroundColor Gray
    Push-Location infra/terraform
    tfsec . --format json --out ../../security-reports/tfsec-report.json --soft-fail 2>&1 | Out-Null
    Pop-Location
    Write-Host "  TFSec scan complete" -ForegroundColor Green
} catch {
    Write-Host "  IaC scan completed with warnings: $_" -ForegroundColor Yellow
}
Write-Host ""

# 4. SAST
Write-Host "[4/6] Running SAST (Semgrep)..." -ForegroundColor Yellow
try {
    semgrep scan --config=auto --json --output security-reports/semgrep-report.json --exclude "node_modules" --exclude "dist" --exclude "build" --exclude ".next" --exclude ".terraform" --exclude ".aws-sam" --exclude "coverage" --quiet 2>&1 | Out-Null
    Write-Host "  SAST scan complete" -ForegroundColor Green
} catch {
    Write-Host "  SAST scan completed with warnings: $_" -ForegroundColor Yellow
}
Write-Host ""

# 5. Generate Report
# 5. DAST (ZAP)
Write-Host "[5/6] Running DAST (ZAP)..." -ForegroundColor Yellow
try {
    if ([string]::IsNullOrWhiteSpace($zapTarget)) {
        Write-Host "  Skipping ZAP - set ZAP_TARGET env var to enable" -ForegroundColor Yellow
    } else {
        $reportsPath = (Join-Path $projectRoot "security-reports")
        $zapVolume = "${reportsPath}:/zap/wrk"
        docker run --rm -v "$zapVolume" -t zaproxy/zap-stable zap-baseline.py -t $zapTarget -J zap-report.json -w zap-warnings.html 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ZAP scan complete" -ForegroundColor Green
        } else {
            Write-Host "  ZAP scan completed with alerts (see zap-report.json)" -ForegroundColor Yellow
        }
    }
} catch {
    Write-Host "  ZAP scan failed: $_" -ForegroundColor Red
}
Write-Host ""

# 6. Generate Report
Write-Host "[6/6] Generating Combined Report..." -ForegroundColor Yellow
try {
    & "$projectRoot\generate-security-report.ps1"
} catch {
    Write-Host "  Report generation failed: $_" -ForegroundColor Red
    Write-Host "  You can try running: .\generate-security-report.ps1" -ForegroundColor Gray
}

Write-Host ""
Write-Host "All Security Scans Complete" -ForegroundColor Green
Write-Host "  Report: security-reports/security-report.html" -ForegroundColor Green
Write-Host "  Raw Data: security-reports/*.json" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "  1. Review the HTML report in your browser" -ForegroundColor White
Write-Host "  2. Address CRITICAL and HIGH severity issues first" -ForegroundColor White
Write-Host "  3. Re-run scans after fixes: .\run-all-scans.ps1" -ForegroundColor White
Write-Host ""
