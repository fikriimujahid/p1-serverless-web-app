# Combined Security Report Generator
# Usage: .\generate-security-report.ps1

$reportDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$projectRoot = $PSScriptRoot
$reportsDir = "$projectRoot\security-reports"

Write-Host "`nGenerating combined security report..." -ForegroundColor Cyan

# Ensure reports directory exists
if (-not (Test-Path $reportsDir)) {
    Write-Host "Error: security-reports directory not found. Run scans first." -ForegroundColor Red
    exit 1
}

# Initialize report
$htmlReport = @"
<!DOCTYPE html>
<html>
<head>
    <title>Security Assessment Report - $reportDate</title>
    <meta charset="UTF-8">
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; line-height: 1.6; }
        .container { max-width: 1400px; margin: 0 auto; background: white; padding: 40px; box-shadow: 0 2px 8px rgba(0,0,0,0.1); }
        
        /* Header */
        .report-header { border-bottom: 4px solid #2c3e50; padding-bottom: 20px; margin-bottom: 30px; }
        .report-header h1 { color: #2c3e50; margin: 0; font-size: 32px; font-weight: 600; }
        .report-header .subtitle { color: #7f8c8d; font-size: 14px; margin-top: 8px; text-transform: uppercase; letter-spacing: 1px; }
        .classification { display: inline-block; background: #e74c3c; color: white; padding: 6px 12px; border-radius: 4px; font-size: 12px; font-weight: bold; margin-top: 10px; }
        
        /* Risk Levels */
        .risk-critical { color: #8B0000; font-weight: bold; }
        .risk-high { color: #e74c3c; font-weight: bold; }
        .risk-medium { color: #f39c12; font-weight: bold; }
        .risk-low { color: #3498db; font-weight: bold; }
        .risk-info { color: #7f8c8d; font-weight: bold; }
        .risk-pass { color: #27ae60; font-weight: bold; }
        
        .badge-critical { background: #8B0000; color: white; padding: 4px 8px; border-radius: 3px; font-size: 11px; font-weight: bold; }
        .badge-high { background: #e74c3c; color: white; padding: 4px 8px; border-radius: 3px; font-size: 11px; font-weight: bold; }
        .badge-medium { background: #f39c12; color: white; padding: 4px 8px; border-radius: 3px; font-size: 11px; font-weight: bold; }
        .badge-low { background: #3498db; color: white; padding: 4px 8px; border-radius: 3px; font-size: 11px; font-weight: bold; }
        .badge-info { background: #95a5a6; color: white; padding: 4px 8px; border-radius: 3px; font-size: 11px; font-weight: bold; }
        
        /* Sections */
        h2 { color: #2c3e50; font-size: 24px; margin-top: 40px; padding-bottom: 10px; border-bottom: 2px solid #3498db; }
        h3 { color: #34495e; font-size: 18px; margin-top: 25px; padding-left: 10px; border-left: 4px solid #3498db; }
        h4 { color: #555; font-size: 16px; margin-top: 20px; }
        
        /* Executive Summary */
        .executive-summary { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 8px; margin: 30px 0; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
        .executive-summary h2 { color: white; border: none; margin: 0 0 20px 0; }
        .risk-score { text-align: center; padding: 20px; background: rgba(255,255,255,0.1); border-radius: 8px; margin: 20px 0; }
        .risk-score-value { font-size: 72px; font-weight: bold; line-height: 1; }
        .risk-score-label { font-size: 14px; opacity: 0.9; text-transform: uppercase; letter-spacing: 2px; margin-top: 10px; }
        
        /* Metrics Grid */
        .metrics-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin: 30px 0; }
        .metric-card { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); border-left: 4px solid #3498db; }
        .metric-card.critical { border-left-color: #8B0000; }
        .metric-card.high { border-left-color: #e74c3c; }
        .metric-card.medium { border-left-color: #f39c12; }
        .metric-card.low { border-left-color: #3498db; }
        .metric-value { font-size: 36px; font-weight: bold; color: #2c3e50; line-height: 1; }
        .metric-label { font-size: 12px; color: #7f8c8d; text-transform: uppercase; letter-spacing: 1px; margin-top: 8px; }
        .metric-change { font-size: 13px; margin-top: 5px; }
        
        /* Tables */
        table { width: 100%; border-collapse: collapse; margin: 20px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }
        th { background: #34495e; color: white; padding: 14px; text-align: left; font-weight: 600; font-size: 13px; text-transform: uppercase; letter-spacing: 0.5px; }
        td { padding: 12px; border-bottom: 1px solid #ecf0f1; font-size: 14px; }
        tr:hover { background: #f8f9fa; }
        tr:last-child td { border-bottom: none; }
        
        /* Status Boxes */
        .status-box { background: #ecf0f1; padding: 20px; border-radius: 6px; margin: 20px 0; border-left: 5px solid #3498db; }
        .status-box.alert { border-left-color: #e74c3c; background: #fee; }
        .status-box.warning { border-left-color: #f39c12; background: #fff3cd; }
        .status-box.success { border-left-color: #27ae60; background: #d4edda; }
        
        /* Recommendations */
        .recommendation { background: white; padding: 20px; margin: 15px 0; border-radius: 6px; border-left: 5px solid #3498db; box-shadow: 0 2px 4px rgba(0,0,0,0.05); }
        .recommendation.critical { border-left-color: #8B0000; }
        .recommendation.high { border-left-color: #e74c3c; }
        .recommendation.medium { border-left-color: #f39c12; }
        .recommendation-title { font-weight: bold; font-size: 16px; margin-bottom: 8px; }
        .recommendation-priority { display: inline-block; margin-bottom: 10px; }
        
        /* Footer */
        .report-footer { margin-top: 60px; padding-top: 30px; border-top: 2px solid #ecf0f1; text-align: center; color: #7f8c8d; font-size: 12px; }
        .report-footer .confidential { color: #e74c3c; font-weight: bold; margin-bottom: 10px; }
        
        /* Links */
        a { color: #3498db; text-decoration: none; }
        a:hover { text-decoration: underline; color: #2980b9; }
        
        /* Print Styles */
        @media print {
            body { background: white; }
            .container { box-shadow: none; }
            .no-print { display: none; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="report-header">
            <h1>Security Assessment Report</h1>
            <div class="subtitle">Comprehensive Application Security Analysis</div>
            <div class="subtitle">Report Date: $reportDate</div>
            <span class="classification">CONFIDENTIAL - INTERNAL USE ONLY</span>
        </div>
        
        <div class="executive-summary">
            <h2>Executive Summary</h2>
"@

# Function to safely parse JSON
function Get-SafeJsonContent {
    param($filePath)
    if (Test-Path $filePath) {
        try {
            return Get-Content $filePath -Raw | ConvertFrom-Json
        } catch {
            Write-Warning "Cannot parse $filePath`: $($_.Exception.Message)"
            Write-Warning "This may be due to duplicate keys in JSON (e.g., 'environment' and 'Environment' in Terraform tags)"
            return $null
        }
    }
    # File doesn't exist - silently return null (expected when scan hasn't run)
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

# Helper: take first N items safely
function Take-First {
    param($collection, $max = 200)
    if (-not $collection) { return @() }
    $arr = @($collection)
    if ($arr.Count -gt $max) { return $arr[0..($max-1)] }
    return $arr
}

# Parse scan results
Write-Host "  Parsing scan results..." -ForegroundColor Gray
$gitleaksData = Get-SafeJsonContent "$reportsDir\gitleaks-report.json"
$backendNpmData = Get-SafeJsonContent "$reportsDir\backend-npm-audit.json"
$frontendNpmData = Get-SafeJsonContent "$reportsDir\frontend-npm-audit.json"
$checkovTerraformData = Get-SafeJsonContent "$reportsDir\terraform\results_json.json"
$checkovSamData = Get-SafeJsonContent "$reportsDir\sam\results_json.json"
$tfsecData = Get-SafeJsonContent "$reportsDir\tfsec-report.json"
$semgrepData = Get-SafeJsonContent "$reportsDir\semgrep-report.json"
$zapData = Get-SafeJsonContent "$reportsDir\zap-report.json"

# Count issues
$secretsCount = Count-Issues $gitleaksData "gitleaks"
$backendVulns = Count-Issues $backendNpmData "npm"
$frontendVulns = Count-Issues $frontendNpmData "npm"
$checkovTerraformFailed = Count-Issues $checkovTerraformData "checkov"
$checkovSamFailed = Count-Issues $checkovSamData "checkov"
$checkovFailed = $checkovTerraformFailed + $checkovSamFailed
$tfsecIssues = if ($tfsecData.results) { ($tfsecData.results | Measure-Object).Count } else { 0 }
$semgrepIssues = Count-Issues $semgrepData "semgrep"
$zapAlerts = @()
if ($zapData -and $zapData.site) {
    foreach ($site in $zapData.site) {
        if ($site.alerts) { $zapAlerts += $site.alerts }
    }
}
$zapIssues = @($zapAlerts).Count

$totalIssues = $secretsCount + $backendVulns + $frontendVulns + $checkovFailed + $tfsecIssues + $semgrepIssues + $zapIssues

# Calculate risk score (0-100, lower is better)
$criticalCount = $secretsCount + $backendCritical + $frontendCritical
$highCount = $backendHigh + $frontendHigh
$riskScore = [math]::Min(100, ($criticalCount * 20) + ($highCount * 10) + ($totalIssues * 2))
$riskLevel = if ($riskScore -ge 80) { "CRITICAL" } elseif ($riskScore -ge 50) { "HIGH" } elseif ($riskScore -ge 20) { "MEDIUM" } else { "LOW" }
$riskColor = if ($riskScore -ge 80) { "#8B0000" } elseif ($riskScore -ge 50) { "#e74c3c" } elseif ($riskScore -ge 20) { "#f39c12" } else { "#27ae60" }

# Add metrics
$htmlReport += @"
            <div class="risk-score">
                <div class="risk-score-value" style="color: $riskColor;">$riskScore</div>
                <div class="risk-score-label">OVERALL RISK SCORE (0-100)</div>
                <div style="font-size: 18px; margin-top: 10px; font-weight: bold;">Risk Level: $riskLevel</div>
            </div>
            <p style="font-size: 14px; opacity: 0.95;">
                This security assessment identified <strong>$totalIssues total findings</strong> across multiple security domains.
                Immediate attention is required for <strong>$criticalCount CRITICAL</strong> and <strong>$highCount HIGH</strong> severity issues.
                This report provides detailed analysis of identified vulnerabilities, misconfigurations, and security weaknesses.
            </p>
        </div>

        <h2>Risk Assessment Summary</h2>
        <div class="metrics-grid">
            <div class="metric-card critical">
                <div class="metric-value">$criticalCount</div>
                <div class="metric-label">Critical Issues</div>
                <div class="metric-change risk-critical">Immediate Action Required</div>
            </div>
            <div class="metric-card high">
                <div class="metric-value">$highCount</div>
                <div class="metric-label">High Priority</div>
                <div class="metric-change risk-high">Remediate Within 7 Days</div>
            </div>
            <div class="metric-card medium">
                <div class="metric-value">$($totalIssues - $criticalCount - $highCount)</div>
                <div class="metric-label">Medium & Low</div>
                <div class="metric-change risk-medium">Address in Sprint Planning</div>
            </div>
            <div class="metric-card">
                <div class="metric-value">$totalIssues</div>
                <div class="metric-label">Total Findings</div>
                <div class="metric-change risk-info">Across All Categories</div>
            </div>
        </div>

        <h2>Findings by Security Domain</h2>
        <table>
            <tr>
                <th>Security Domain</th>
                <th style="text-align: center;">Critical</th>
                <th style="text-align: center;">High</th>
                <th style="text-align: center;">Medium</th>
                <th style="text-align: center;">Low</th>
                <th style="text-align: center;">Total</th>
                <th>Status</th>
            </tr>
            <tr>
                <td><strong>Secrets & Credentials</strong></td>
                <td style="text-align: center;">$(if($secretsCount -gt 0){$secretsCount}else{"-"})</td>
                <td style="text-align: center;">-</td>
                <td style="text-align: center;">-</td>
                <td style="text-align: center;">-</td>
                <td style="text-align: center;"><strong>$secretsCount</strong></td>
                <td>$(if($secretsCount -eq 0){"<span class='risk-pass'>PASS</span>"}else{"<span class='risk-critical'>FAIL</span>"})</td>
            </tr>
            <tr>
                <td><strong>Dependency Vulnerabilities</strong></td>
                <td style="text-align: center;">$(if(($backendCritical + $frontendCritical) -gt 0){$backendCritical + $frontendCritical}else{"-"})</td>
                <td style="text-align: center;">$(if(($backendHigh + $frontendHigh) -gt 0){$backendHigh + $frontendHigh}else{"-"})</td>
                <td style="text-align: center;">$(if(($backendModerate + $frontendModerate) -gt 0){$backendModerate + $frontendModerate}else{"-"})</td>
                <td style="text-align: center;">$(if(($backendLow + $frontendLow) -gt 0){$backendLow + $frontendLow}else{"-"})</td>
                <td style="text-align: center;"><strong>$($backendVulns + $frontendVulns)</strong></td>
                <td>$(if(($backendVulns + $frontendVulns) -eq 0){"<span class='risk-pass'>PASS</span>"}elseif(($backendCritical + $frontendCritical) -gt 0){"<span class='risk-critical'>FAIL</span>"}elseif(($backendHigh + $frontendHigh) -gt 0){"<span class='risk-high'>HIGH</span>"}else{"<span class='risk-medium'>REVIEW</span>"})</td>
            </tr>
            <tr>
                <td><strong>Infrastructure Security</strong></td>
                <td style="text-align: center;">-</td>
                <td style="text-align: center;">-</td>
                <td style="text-align: center;">$(if(($checkovFailed + $tfsecIssues) -gt 0){$checkovFailed + $tfsecIssues}else{"-"})</td>
                <td style="text-align: center;">-</td>
                <td style="text-align: center;"><strong>$($checkovFailed + $tfsecIssues)</strong></td>
                <td>$(if(($checkovFailed + $tfsecIssues) -eq 0){"<span class='risk-pass'>PASS</span>"}else{"<span class='risk-medium'>REVIEW</span>"})</td>
            </tr>
            <tr>
                <td><strong>Application Security (SAST)</strong></td>
                <td style="text-align: center;">-</td>
                <td style="text-align: center;">-</td>
                <td style="text-align: center;">$(if($semgrepIssues -gt 0){$semgrepIssues}else{"-"})</td>
                <td style="text-align: center;">-</td>
                <td style="text-align: center;"><strong>$semgrepIssues</strong></td>
                <td>$(if($semgrepIssues -eq 0){"<span class='risk-pass'>PASS</span>"}else{"<span class='risk-medium'>REVIEW</span>"})</td>
            </tr>
            <tr>
                <td><strong>Runtime Security (DAST)</strong></td>
                <td style="text-align: center;">-</td>
                <td style="text-align: center;">-</td>
                <td style="text-align: center;">$(if($zapIssues -gt 0){$zapIssues}else{"-"})</td>
                <td style="text-align: center;">-</td>
                <td style="text-align: center;"><strong>$zapIssues</strong></td>
                <td>$(if($zapIssues -eq 0){"<span class='risk-pass'>PASS</span>"}else{"<span class='risk-medium'>REVIEW</span>"})</td>
            </tr>
        </table>

        <h2>Detailed Findings</h2>
"@

# Secrets Scanning Results
$htmlReport += @"
        <h3>1. Secrets & Credential Exposure Analysis</h3>
        <p><strong>Tool:</strong> Gitleaks | <strong>Scope:</strong> Source Code Repository</p>
        <div class="status-box $(if($secretsCount -eq 0){'success'}else{'alert'})">
            <strong>Assessment:</strong> $(if($secretsCount -eq 0){"No exposed credentials detected. Repository passed secrets scanning validation."}else{"<span class='risk-critical'>CRITICAL - $secretsCount exposed credential(s) identified. Immediate remediation required.</span>"})
        </div>
        <table>
            <tr><th>Finding Type</th><th>Value</th></tr>
            <tr><td>Exposed Secrets Detected</td><td><strong>$secretsCount</strong></td></tr>
            <tr><td>Risk Level</td><td>$(if($secretsCount -eq 0){"<span class='badge-info'>PASS</span>"}else{"<span class='badge-critical'>CRITICAL</span>"})</td></tr>
            <tr><td>Compliance Impact</td><td>$(if($secretsCount -eq 0){"No impact"}else{"SOC 2, PCI DSS, GDPR violations possible"})</td></tr>
            <tr><td>Detailed Report</td><td><a href='gitleaks-report.json' target='_blank'>gitleaks-report.json</a></td></tr>
        </table>
        
        <h4>Identified Exposures</h4>
        <table>
            <tr><th>File Path</th><th>Line</th><th>Detection Rule</th><th>Classification</th></tr>
"@

$gitleaksRows = Take-First $gitleaksData 200
$gitleaksCount = @($gitleaksRows).Count
foreach ($f in $gitleaksRows) {
    $file = if ($f.File) { $f.File } elseif ($f.file) { $f.file } else { "N/A" }
    $line = if ($f.StartLine) { $f.StartLine } elseif ($f.Line) { $f.Line } else { "N/A" }
    $rule = if ($f.RuleID) { $f.RuleID } elseif ($f.Rule) { $f.Rule } elseif ($f.rule) { $f.rule } else { "N/A" }
    $desc = if ($f.Description) { $f.Description } else { "Potential secret detected" }
    $htmlReport += "            <tr><td><code>$file</code></td><td>$line</td><td>$rule</td><td><span class='badge-critical'>SECRET</span> $desc</td></tr>" + "`n"
}
$htmlReport += if ($gitleaksCount -eq 0) { "            <tr><td colspan='4' style='text-align: center; color: #27ae60;'><strong>No credential exposures detected</strong></td></tr>`n" } else { "" }
$htmlReport += @"
        </table>
"@

# Dependency Scanning Results
$backendCritical = if($backendNpmData.metadata.vulnerabilities.critical){$backendNpmData.metadata.vulnerabilities.critical}else{0}
$backendHigh = if($backendNpmData.metadata.vulnerabilities.high){$backendNpmData.metadata.vulnerabilities.high}else{0}
$backendModerate = if($backendNpmData.metadata.vulnerabilities.moderate){$backendNpmData.metadata.vulnerabilities.moderate}else{0}
$backendLow = if($backendNpmData.metadata.vulnerabilities.low){$backendNpmData.metadata.vulnerabilities.low}else{0}

$frontendCritical = if($frontendNpmData.metadata.vulnerabilities.critical){$frontendNpmData.metadata.vulnerabilities.critical}else{0}
$frontendHigh = if($frontendNpmData.metadata.vulnerabilities.high){$frontendNpmData.metadata.vulnerabilities.high}else{0}
$frontendModerate = if($frontendNpmData.metadata.vulnerabilities.moderate){$frontendNpmData.metadata.vulnerabilities.moderate}else{0}
$frontendLow = if($frontendNpmData.metadata.vulnerabilities.low){$frontendNpmData.metadata.vulnerabilities.low}else{0}

$totalCritical = $backendCritical + $frontendCritical
$totalHigh = $backendHigh + $frontendHigh
$totalVulns = $backendVulns + $frontendVulns

$htmlReport += @"
        <h3>2. Software Composition Analysis (SCA)</h3>
        <p><strong>Tool:</strong> npm audit | <strong>Scope:</strong> Application Dependencies (Backend + Frontend)</p>
        <div class="status-box $(if($totalVulns -eq 0){'success'}elseif($totalCritical -gt 0 -or $totalHigh -gt 0){'alert'}else{'warning'})">
            <strong>Assessment:</strong> $(if($totalVulns -eq 0){"All dependencies are up-to-date with no known vulnerabilities."}elseif($totalCritical -gt 0){"<span class='risk-critical'>CRITICAL - $totalCritical critical vulnerabilities require immediate patching.</span>"}elseif($totalHigh -gt 0){"<span class='risk-high'>HIGH - $totalHigh high-severity vulnerabilities identified.</span>"}else{"Medium/Low severity vulnerabilities detected. Schedule remediation in next sprint."})
        </div>
        <table>
            <tr>
                <th>Component</th>
                <th style="text-align: center;">Critical</th>
                <th style="text-align: center;">High</th>
                <th style="text-align: center;">Medium</th>
                <th style="text-align: center;">Low</th>
                <th style="text-align: center;">Total</th>
                <th>Risk Assessment</th>
                <th>SLA</th>
            </tr>
            <tr>
                <td><strong>Backend Services</strong></td>
                <td style="text-align: center;">$(if($backendCritical -gt 0){"<span class='badge-critical'>$backendCritical</span>"}else{"-"})</td>
                <td style="text-align: center;">$(if($backendHigh -gt 0){"<span class='badge-high'>$backendHigh</span>"}else{"-"})</td>
                <td style="text-align: center;">$(if($backendModerate -gt 0){"<span class='badge-medium'>$backendModerate</span>"}else{"-"})</td>
                <td style="text-align: center;">$(if($backendLow -gt 0){"<span class='badge-low'>$backendLow</span>"}else{"-"})</td>
                <td style="text-align: center;"><strong>$backendVulns</strong></td>
                <td>$(if($backendVulns -eq 0){"<span class='risk-pass'>SECURE</span>"}elseif($backendCritical -gt 0){"<span class='risk-critical'>CRITICAL</span>"}elseif($backendHigh -gt 0){"<span class='risk-high'>HIGH RISK</span>"}else{"<span class='risk-medium'>MODERATE</span>"})</td>
                <td>$(if($backendCritical -gt 0 -or $backendHigh -gt 0){"24-48 hrs"}elseif($backendModerate -gt 0){"7 days"}else{"-"})</td>
            </tr>
            <tr>
                <td><strong>Frontend Application</strong></td>
                <td style="text-align: center;">$(if($frontendCritical -gt 0){"<span class='badge-critical'>$frontendCritical</span>"}else{"-"})</td>
                <td style="text-align: center;">$(if($frontendHigh -gt 0){"<span class='badge-high'>$frontendHigh</span>"}else{"-"})</td>
                <td style="text-align: center;">$(if($frontendModerate -gt 0){"<span class='badge-medium'>$frontendModerate</span>"}else{"-"})</td>
                <td style="text-align: center;">$(if($frontendLow -gt 0){"<span class='badge-low'>$frontendLow</span>"}else{"-"})</td>
                <td style="text-align: center;"><strong>$frontendVulns</strong></td>
                <td>$(if($frontendVulns -eq 0){"<span class='risk-pass'>SECURE</span>"}elseif($frontendCritical -gt 0){"<span class='risk-critical'>CRITICAL</span>"}elseif($frontendHigh -gt 0){"<span class='risk-high'>HIGH RISK</span>"}else{"<span class='risk-medium'>MODERATE</span>"})</td>
                <td>$(if($frontendCritical -gt 0 -or $frontendHigh -gt 0){"24-48 hrs"}elseif($frontendModerate -gt 0){"7 days"}else{"-"})</td>
            </tr>
        </table>
        <p><strong>References:</strong> <a href='backend-npm-audit.json' target='_blank'>Backend Audit Report</a> | <a href='frontend-npm-audit.json' target='_blank'>Frontend Audit Report</a> | <a href='https://nvd.nist.gov/' target='_blank'>NVD Database</a></p>
        
        <h4>Vulnerable Dependencies - Backend</h4>
        <table>
            <tr><th>Package Name</th><th>Severity</th><th>Affected Paths</th><th>Recommendation</th></tr>
"@

$backendVulnProps = @()
if ($backendNpmData -and $backendNpmData.vulnerabilities) { $backendVulnProps = $backendNpmData.vulnerabilities.PSObject.Properties }
$backendVulnCount = @($backendVulnProps).Count
foreach ($v in Take-First $backendVulnProps 200) {
    $pkg = $v.Name
    $sev = $v.Value.severity
    $viaCount = if ($v.Value.via) { @($v.Value.via).Count } else { 0 }
    $badge = switch ($sev) {
        "critical" { "<span class='badge-critical'>CRITICAL</span>" }
        "high" { "<span class='badge-high'>HIGH</span>" }
        "moderate" { "<span class='badge-medium'>MEDIUM</span>" }
        "low" { "<span class='badge-low'>LOW</span>" }
        default { "<span class='badge-info'>INFO</span>" }
    }
    $action = switch ($sev) {
        "critical" { "Update immediately" }
        "high" { "Patch within 48h" }
        "moderate" { "Schedule update" }
        default { "Monitor for updates" }
    }
    $htmlReport += "            <tr><td><code>$pkg</code></td><td>$badge</td><td>$viaCount dependency path(s)</td><td>$action</td></tr>" + "`n"
}
$htmlReport += if ($backendVulnCount -eq 0) { "            <tr><td colspan='4' style='text-align: center; color: #27ae60;'><strong>No vulnerabilities detected</strong></td></tr>`n" } else { "" }
$htmlReport += @"
        </table>
        
        <h4>Vulnerable Dependencies - Frontend</h4>
        <table>
            <tr><th>Package Name</th><th>Severity</th><th>Affected Paths</th><th>Recommendation</th></tr>
"@

$frontendVulnProps = @()
if ($frontendNpmData -and $frontendNpmData.vulnerabilities) { $frontendVulnProps = $frontendNpmData.vulnerabilities.PSObject.Properties }
$frontendVulnCount = @($frontendVulnProps).Count
foreach ($v in Take-First $frontendVulnProps 200) {
    $pkg = $v.Name
    $sev = $v.Value.severity
    $viaCount = if ($v.Value.via) { @($v.Value.via).Count } else { 0 }
    $badge = switch ($sev) {
        "critical" { "<span class='badge-critical'>CRITICAL</span>" }
        "high" { "<span class='badge-high'>HIGH</span>" }
        "moderate" { "<span class='badge-medium'>MEDIUM</span>" }
        "low" { "<span class='badge-low'>LOW</span>" }
        default { "<span class='badge-info'>INFO</span>" }
    }
    $action = switch ($sev) {
        "critical" { "Update immediately" }
        "high" { "Patch within 48h" }
        "moderate" { "Schedule update" }
        default { "Monitor for updates" }
    }
    $htmlReport += "            <tr><td><code>$pkg</code></td><td>$badge</td><td>$viaCount dependency path(s)</td><td>$action</td></tr>" + "`n"
}
$htmlReport += if ($frontendVulnCount -eq 0) { "            <tr><td colspan='4' style='text-align: center; color: #27ae60;'><strong>No vulnerabilities detected</strong></td></tr>`n" } else { "" }
$htmlReport += @"
        </table>
"@

# IaC Scanning Results
$checkovTerraformPassed = if($checkovTerraformData.summary.passed){$checkovTerraformData.summary.passed}else{0}
$checkovSamPassed = if($checkovSamData.summary.passed){$checkovSamData.summary.passed}else{0}
$checkovPassed = $checkovTerraformPassed + $checkovSamPassed

$checkovTerraformSkipped = if($checkovTerraformData.summary.skipped){$checkovTerraformData.summary.skipped}else{0}
$checkovSamSkipped = if($checkovSamData.summary.skipped){$checkovSamData.summary.skipped}else{0}
$checkovSkipped = $checkovTerraformSkipped + $checkovSamSkipped

$htmlReport += @"
        <h3>3. Infrastructure Security Configuration Assessment</h3>
        <p><strong>Tools:</strong> Checkov, TFSec | <strong>Scope:</strong> Terraform Infrastructure & SAM Serverless Templates</p>
        <div class="status-box $(if(($checkovFailed + $tfsecIssues) -eq 0){'success'}else{'warning'})">
            <strong>Assessment:</strong> $(if(($checkovFailed + $tfsecIssues) -eq 0){"Infrastructure-as-Code passed all security policy checks."}else{"$($checkovFailed + $tfsecIssues) security misconfigurations detected. Review recommended for compliance and hardening."})
        </div>
        <table>
            <tr>
                <th>Scanner</th>
                <th>Target</th>
                <th style="text-align: center;">Compliant</th>
                <th style="text-align: center;">Non-Compliant</th>
                <th style="text-align: center;">Skipped</th>
                <th>Assessment</th>
                <th>Impact</th>
            </tr>
            <tr>
                <td rowspan="2"><strong>Checkov</strong><br><small>Policy Enforcement</small></td>
                <td>Terraform (AWS)</td>
                <td style="text-align: center;">$checkovTerraformPassed</td>
                <td style="text-align: center;">$(if($checkovTerraformFailed -gt 0){"<span class='badge-medium'>$checkovTerraformFailed</span>"}else{"0"})</td>
                <td style="text-align: center;">$checkovTerraformSkipped</td>
                <td>$(if($checkovTerraformFailed -eq 0){"<span class='risk-pass'>COMPLIANT</span>"}else{"<span class='risk-medium'>REVIEW REQUIRED</span>"})</td>
                <td>Configuration hardening</td>
            </tr>
            <tr>
                <td>SAM Template</td>
                <td style="text-align: center;">$checkovSamPassed</td>
                <td style="text-align: center;">$(if($checkovSamFailed -gt 0){"<span class='badge-medium'>$checkovSamFailed</span>"}else{"0"})</td>
                <td style="text-align: center;">$checkovSamSkipped</td>
                <td>$(if($checkovSamFailed -eq 0){"<span class='risk-pass'>COMPLIANT</span>"}else{"<span class='risk-medium'>REVIEW REQUIRED</span>"})</td>
                <td>Serverless security</td>
            </tr>
            <tr>
                <td><strong>TFSec</strong><br><small>Terraform Security</small></td>
                <td>Terraform</td>
                <td style="text-align: center;">-</td>
                <td style="text-align: center;">$(if($tfsecIssues -gt 0){"<span class='badge-medium'>$tfsecIssues</span>"}else{"0"})</td>
                <td style="text-align: center;">-</td>
                <td>$(if($tfsecIssues -eq 0){"<span class='risk-pass'>SECURE</span>"}else{"<span class='risk-medium'>REVIEW REQUIRED</span>"})</td>
                <td>AWS best practices</td>
            </tr>
        </table>
        <p><strong>References:</strong> <a href='terraform/results_json.json' target='_blank'>Terraform Checkov</a> | <a href='sam/results_json.json' target='_blank'>SAM Checkov</a> | <a href='tfsec-report.json' target='_blank'>TFSec Report</a> | <a href='https://www.checkov.io/' target='_blank'>Checkov Docs</a></p>
        
        <h4>Configuration Findings - Terraform Infrastructure</h4>
        <table>
            <tr><th>Policy ID</th><th>AWS Resource</th><th>File Location</th><th>Classification</th><th>Security Control</th></tr>
"@

$checkovTerraformFindings = @()
if ($checkovTerraformData.results -and $checkovTerraformData.results.failed_checks) { $checkovTerraformFindings = $checkovTerraformData.results.failed_checks }
$checkovTerraformCount = @($checkovTerraformFindings).Count
foreach ($c in Take-First $checkovTerraformFindings 200) {
    $cid = if ($c.check_id) { $c.check_id } else { "N/A" }
    $res = if ($c.resource) { $c.resource } else { "N/A" }
    $file = if ($c.file_path) { $c.file_path } else { "N/A" }
    $sev = if ($c.severity) { $c.severity } else { "MEDIUM" }
    $msg = if ($c.check_name) { $c.check_name } else { "Security check failed" }
    $badge = "<span class='badge-medium'>$sev</span>"
    $htmlReport += "            <tr><td><code>$cid</code></td><td><code>$res</code></td><td>$file</td><td>$badge</td><td>$msg</td></tr>" + "`n"
}
$htmlReport += if ($checkovTerraformCount -eq 0) { "            <tr><td colspan='5' style='text-align: center; color: #27ae60;'><strong>All Terraform resources comply with security policies</strong></td></tr>`n" } else { "" }
$htmlReport += @"
        </table>
        
        <h4>Configuration Findings - SAM Serverless</h4>
        <table>
            <tr><th>Policy ID</th><th>Resource</th><th>File Location</th><th>Classification</th><th>Security Control</th></tr>
"@

$checkovSamFindings = @()
if ($checkovSamData.results -and $checkovSamData.results.failed_checks) { $checkovSamFindings = $checkovSamData.results.failed_checks }
$checkovSamCount = @($checkovSamFindings).Count
foreach ($c in Take-First $checkovSamFindings 200) {
    $cid = $c.check_id
    $res = $c.resource
    $file = $c.file_path
    $sev = $c.severity
    $msg = $c.check_name
    $htmlReport += "            <tr><td>$cid</td><td>$res</td><td>$file</td><td>$sev</td><td>$msg</td></tr>" + "`n"
}
$htmlReport += if ($checkovSamCount -eq 0) { "            <tr><td colspan='5'>No issues found</td></tr>`n" } else { "" }
$htmlReport += @"
        </table>
        <h5>TFSec</h5>
        <table>
            <tr><th>Rule ID</th><th>File</th><th>Line</th><th>Severity</th><th>Description</th></tr>
"@

$tfsecFindings = @()
if ($tfsecData.results) { $tfsecFindings = $tfsecData.results }
$tfsecCount = @($tfsecFindings).Count
foreach ($t in Take-First $tfsecFindings 200) {
    $rid = if ($t.rule_id) { $t.rule_id } else { "" }
    $file = if ($t.location -and $t.location.filename) { $t.location.filename } else { "" }
    $line = if ($t.location -and $t.location.start_line) { $t.location.start_line } else { "" }
    $sev = if ($t.severity) { $t.severity } else { "" }
    $desc = if ($t.description) { $t.description } else { "" }
    $htmlReport += "            <tr><td>$rid</td><td>$file</td><td>$line</td><td>$sev</td><td>$desc</td></tr>" + "`n"
}
$htmlReport += if ($tfsecCount -eq 0) { "            <tr><td colspan='5'>No issues found</td></tr>`n" } else { "" }
$htmlReport += @"
        </table>
"@

# SAST Results
$htmlReport += @"
        <h3>4. Static Application Security Testing (SAST)</h3>
        <p><strong>Tool:</strong> Semgrep | <strong>Scope:</strong> Application Source Code (Backend & Frontend)</p>
        <div class="status-box $(if($semgrepIssues -eq 0){'success'}else{'warning'})">
            <strong>Assessment:</strong> $(if($semgrepIssues -eq 0){"Source code analysis completed with no security vulnerabilities detected."}else{"$semgrepIssues potential code-level security issues identified for review."})
        </div>
        <table>
            <tr><th>Analysis Metric</th><th>Value</th></tr>
            <tr><td>Total Findings</td><td><strong>$semgrepIssues</strong></td></tr>
            <tr><td>Risk Level</td><td>$(if($semgrepIssues -eq 0){"<span class='risk-pass'>SECURE</span>"}else{"<span class='risk-medium'>REVIEW REQUIRED</span>"})</td></tr>
            <tr><td>Coverage</td><td>TypeScript, JavaScript, Python</td></tr>
            <tr><td>Detection Focus</td><td>Injection, XSS, Authentication, Cryptography</td></tr>
            <tr><td>Detailed Report</td><td><a href='semgrep-report.json' target='_blank'>semgrep-report.json</a></td></tr>
        </table>
        
        <h4>Code Security Findings</h4>
        <table>
            <tr><th>Rule ID</th><th>File Path</th><th>Line</th><th>Classification</th><th>Description</th></tr>
"@

$semgrepFindings = @()
if ($semgrepData.results) { $semgrepFindings = $semgrepData.results }
$semgrepCount = @($semgrepFindings).Count
foreach ($s in Take-First $semgrepFindings 200) {
    $rule = if ($s.check_id) { $s.check_id } else { "N/A" }
    $file = if ($s.path) { $s.path } else { "N/A" }
    $line = if ($s.start -and $s.start.line) { $s.start.line } else { "N/A" }
    $sev = if ($s.extra -and $s.extra.severity) { $s.extra.severity } else { "INFO" }
    $msg = if ($s.extra -and $s.extra.message) { $s.extra.message } else { "Security pattern detected" }
    $badge = switch ($sev.ToUpper()) {
        "ERROR" { "<span class='badge-high'>HIGH</span>" }
        "WARNING" { "<span class='badge-medium'>MEDIUM</span>" }
        "INFO" { "<span class='badge-info'>INFO</span>" }
        default { "<span class='badge-info'>$sev</span>" }
    }
    $htmlReport += "            <tr><td><code>$rule</code></td><td><code>$file</code></td><td>$line</td><td>$badge</td><td>$msg</td></tr>" + "`n"
}
$htmlReport += if ($semgrepCount -eq 0) { "            <tr><td colspan='5' style='text-align: center; color: #27ae60;'><strong>No code-level security issues detected</strong></td></tr>`n" } else { "" }
$htmlReport += @"
        </table>
"@

# DAST Results
$htmlReport += @"
        <h3>5. Dynamic Application Security Testing (DAST)</h3>
        <p><strong>Tool:</strong> OWASP ZAP | <strong>Scope:</strong> Production Application Runtime Analysis</p>
        <div class="status-box $(if($zapIssues -eq 0){'success'}else{'warning'})">
            <strong>Assessment:</strong> $(if($zapIssues -eq 0){"Application runtime testing completed with no active vulnerabilities detected."}else{"$zapIssues security alerts identified during active scanning. Review recommended."})
        </div>
        <table>
            <tr><th>Scan Metric</th><th>Value</th></tr>
            <tr><td>Total Alerts</td><td><strong>$zapIssues</strong></td></tr>
            <tr><td>Risk Level</td><td>$(if($zapIssues -eq 0){"<span class='risk-pass'>SECURE</span>"}else{"<span class='risk-medium'>REVIEW REQUIRED</span>"})</td></tr>
            <tr><td>Scan Type</td><td>Baseline Passive + Active Scanning</td></tr>
            <tr><td>Detection Focus</td><td>OWASP Top 10, Headers, Authentication, XSS, Injection</td></tr>
            <tr><td>Detailed Report</td><td><a href='zap-report.json' target='_blank'>zap-report.json</a></td></tr>
        </table>
        
        <h4>Runtime Security Alerts</h4>
        <table>
            <tr><th>Alert Name</th><th>Risk Level</th><th>Endpoint</th><th>Parameter</th><th>Evidence</th></tr>
"@

$zapCount = $zapIssues
foreach ($a in Take-First $zapAlerts 200) {
    $alert = if ($a.alert) { $a.alert } else { "Unknown Alert" }
    $risk = if ($a.risk) { $a.risk } elseif ($a.riskdesc) { ($a.riskdesc -split ' ')[0] } else { "Medium" }
    $instance = if ($a.instances) { $a.instances[0] } else { $null }
    $url = if ($instance -and $instance.uri) { $instance.uri } else { "N/A" }
    $param = if ($instance -and $instance.param) { $instance.param } else { "-" }
    $otherinfo = if ($instance -and $instance.otherinfo) { 
        $instance.otherinfo
    } else { "-" }
    # Escape HTML special characters in otherinfo
    $otherinfo = [System.Net.WebUtility]::HtmlEncode($otherinfo)
    $badge = switch ($risk.ToUpper()) {
        "HIGH" { "<span class='badge-high'>HIGH</span>" }
        "MEDIUM" { "<span class='badge-medium'>MEDIUM</span>" }
        "LOW" { "<span class='badge-low'>LOW</span>" }
        "INFORMATIONAL" { "<span class='badge-info'>INFO</span>" }
        default { "<span class='badge-info'>$risk</span>" }
    }
    $htmlReport += "            <tr><td>$alert</td><td>$badge</td><td style='word-break: break-all;'><small>$url</small></td><td><code>$param</code></td><td><small>$otherinfo</small></td></tr>" + "`n"
}
$htmlReport += if ($zapCount -eq 0) { "            <tr><td colspan='5' style='text-align: center; color: #27ae60;'><strong>No runtime vulnerabilities detected</strong></td></tr>`n" } else { "" }
$htmlReport += "`n        </table>`n"

$htmlReport += @"
        <hr style="margin: 40px 0; border: none; border-top: 2px solid #ecf0f1;">

        <h2>Remediation Recommendations</h2>
        <p>The following recommendations are prioritized based on risk severity and potential impact. Critical and High severity items require immediate attention.</p>
"@

if ($secretsCount -gt 0) {
    $htmlReport += @"
        <div class="recommendation critical">
            <div class="recommendation-priority"><span class="badge-critical">P0 - CRITICAL</span></div>
            <div class="recommendation-title">Exposed Credentials Remediation</div>
            <p><strong>Finding:</strong> $secretsCount hardcoded credential(s) detected in source code repository.</p>
            <p><strong>Risk:</strong> Exposed credentials can lead to unauthorized access, data breaches, and compliance violations (SOC 2, PCI DSS, GDPR).</p>
            <p><strong>Remediation Steps:</strong></p>
            <ol>
                <li>Immediately rotate all exposed credentials and API keys</li>
                <li>Remove credentials from source code and commit history (use git-filter-repo or BFG Repo-Cleaner)</li>
                <li>Implement secret management solution (AWS Secrets Manager, Azure Key Vault, HashiCorp Vault)</li>
                <li>Configure pre-commit hooks to prevent future credential commits</li>
                <li>Review access logs for unauthorized access attempts</li>
            </ol>
            <p><strong>Timeline:</strong> Immediate (within 4 hours)</p>
        </div>
"@
}

if (($backendCritical -gt 0) -or ($frontendCritical -gt 0)) {
    $htmlReport += @"
        <div class="recommendation critical">
            <div class="recommendation-priority"><span class="badge-critical">P0 - CRITICAL</span></div>
            <div class="recommendation-title">Critical Dependency Vulnerabilities</div>
            <p><strong>Finding:</strong> $($backendCritical + $frontendCritical) critical severity vulnerabilities in application dependencies.</p>
            <p><strong>Risk:</strong> Known exploitable vulnerabilities with public exploits available. High probability of exploitation.</p>
            <p><strong>Remediation Steps:</strong></p>
            <ol>
                <li>Review each critical CVE and assess exploitability in current environment</li>
                <li>Update affected packages: <code>npm audit fix --force</code> (test in dev first)</li>
                <li>If updates break compatibility, implement compensating controls or backport patches</li>
                <li>Deploy updates through standard change management process</li>
                <li>Verify fixes with follow-up scan</li>
            </ol>
            <p><strong>Timeline:</strong> 24-48 hours</p>
        </div>
"@
}

if (($backendHigh -gt 0) -or ($frontendHigh -gt 0)) {
    $htmlReport += @"
        <div class="recommendation high">
            <div class="recommendation-priority"><span class="badge-high">P1 - HIGH</span></div>
            <div class="recommendation-title">High Severity Dependency Updates</div>
            <p><strong>Finding:</strong> $($backendHigh + $frontendHigh) high severity vulnerabilities requiring remediation.</p>
            <p><strong>Risk:</strong> Significant security weaknesses that could be exploited under certain conditions.</p>
            <p><strong>Remediation Steps:</strong></p>
            <ol>
                <li>Prioritize updates based on package usage and exposure</li>
                <li>Test updates in development/staging environments</li>
                <li>Schedule production deployment during maintenance window</li>
                <li>Document any packages that cannot be updated immediately</li>
            </ol>
            <p><strong>Timeline:</strong> Within 7 days</p>
        </div>
"@
}

if ($checkovFailed -gt 0 -or $tfsecIssues -gt 0) {
    $htmlReport += @"
        <div class="recommendation medium">
            <div class="recommendation-priority"><span class="badge-medium">P2 - MEDIUM</span></div>
            <div class="recommendation-title">Infrastructure Security Hardening</div>
            <p><strong>Finding:</strong> $($checkovFailed + $tfsecIssues) infrastructure security misconfigurations detected.</p>
            <p><strong>Risk:</strong> Security misconfigurations may lead to data exposure, insufficient logging, or compliance violations.</p>
            <p><strong>Remediation Steps:</strong></p>
            <ol>
                <li>Review detailed IaC findings and prioritize based on data sensitivity</li>
                <li>Implement recommended security controls (encryption, logging, access controls)</li>
                <li>Update Terraform/CloudFormation templates with security best practices</li>
                <li>Enable AWS Security Hub/Azure Security Center for continuous monitoring</li>
                <li>Document accepted risks for findings that cannot be remediated</li>
            </ol>
            <p><strong>Timeline:</strong> Within 30 days</p>
        </div>
"@
}

if ($semgrepIssues -gt 0) {
    $htmlReport += @"
        <div class="recommendation medium">
            <div class="recommendation-priority"><span class="badge-medium">P2 - MEDIUM</span></div>
            <div class="recommendation-title">Application Code Security Issues</div>
            <p><strong>Finding:</strong> $semgrepIssues potential security weaknesses in application code.</p>
            <p><strong>Risk:</strong> Code-level vulnerabilities may lead to injection attacks, XSS, or logic flaws.</p>
            <p><strong>Remediation Steps:</strong></p>
            <ol>
                <li>Review Semgrep findings for false positives vs. true vulnerabilities</li>
                <li>Implement input validation and output encoding where missing</li>
                <li>Apply secure coding practices (parameterized queries, HTTPS enforcement, etc.)</li>
                <li>Add security test cases for identified weaknesses</li>
                <li>Integrate SAST scanning into CI/CD pipeline</li>
            </ol>
            <p><strong>Timeline:</strong> Within 30 days</p>
        </div>
"@
}

if ($zapIssues -gt 0) {
    $htmlReport += @"
        <div class="recommendation medium">
            <div class="recommendation-priority"><span class="badge-medium">P2 - MEDIUM</span></div>
            <div class="recommendation-title">Runtime Security Findings</div>
            <p><strong>Finding:</strong> $zapIssues security alerts identified during dynamic testing.</p>
            <p><strong>Risk:</strong> Runtime vulnerabilities may be exploitable by external attackers.</p>
            <p><strong>Remediation Steps:</strong></p>
            <ol>
                <li>Review ZAP findings and classify by severity</li>
                <li>Implement security headers (CSP, X-Frame-Options, HSTS)</li>
                <li>Address missing security configurations (HTTPS, secure cookies)</li>
                <li>Conduct manual penetration testing for high-risk findings</li>
                <li>Integrate DAST scanning into deployment pipeline</li>
            </ol>
            <p><strong>Timeline:</strong> Within 30 days</p>
        </div>
"@
}

if ($totalIssues -eq 0) {
    $htmlReport += @"
        <div class="recommendation success">
            <div class="recommendation-priority"><span class="risk-pass">EXCELLENT</span></div>
            <div class="recommendation-title">Security Posture: Strong</div>
            <p>No security issues detected across all testing domains. Current security controls are effective.</p>
            <p><strong>Ongoing Actions:</strong></p>
            <ul>
                <li>Continue regular security scanning (weekly recommended)</li>
                <li>Monitor for new CVEs affecting dependencies</li>
                <li>Maintain security best practices in development lifecycle</li>
                <li>Schedule quarterly penetration testing</li>
                <li>Review and update security policies annually</li>
            </ul>
        </div>
"@
}

$htmlReport += @"

        <h2>Supporting Documentation</h2>
        <p>Detailed technical reports and raw scan data are available in JSON format for further analysis:</p>
        <table>
            <tr><th>Security Domain</th><th>Tool</th><th>Report</th></tr>
            <tr><td>Secrets Detection</td><td>Gitleaks</td><td><a href='gitleaks-report.json' target='_blank'>gitleaks-report.json</a></td></tr>
            <tr><td>Dependency Analysis</td><td>npm audit</td><td><a href='backend-npm-audit.json' target='_blank'>backend-npm-audit.json</a>, <a href='frontend-npm-audit.json' target='_blank'>frontend-npm-audit.json</a></td></tr>
            <tr><td>Infrastructure Security</td><td>Checkov</td><td><a href='terraform/results_json.json' target='_blank'>terraform-checkov.json</a>, <a href='sam/results_json.json' target='_blank'>sam-checkov.json</a></td></tr>
            <tr><td>Infrastructure Security</td><td>TFSec</td><td><a href='tfsec-report.json' target='_blank'>tfsec-report.json</a></td></tr>
            <tr><td>Static Analysis</td><td>Semgrep</td><td><a href='semgrep-report.json' target='_blank'>semgrep-report.json</a></td></tr>
            <tr><td>Dynamic Analysis</td><td>OWASP ZAP</td><td><a href='zap-report.json' target='_blank'>zap-report.json</a></td></tr>
        </table>

        <h2>Compliance & Standards</h2>
        <p>This security assessment covers controls relevant to the following compliance frameworks:</p>
        <ul>
            <li><strong>OWASP Top 10 (2021):</strong> Coverage of injection, broken authentication, XSS, and other web vulnerabilities</li>
            <li><strong>CIS Benchmarks:</strong> Infrastructure hardening and configuration management</li>
            <li><strong>NIST CSF:</strong> Identify, Protect, Detect, Respond, Recover controls</li>
            <li><strong>PCI DSS:</strong> Secrets management, encryption, access controls</li>
            <li><strong>SOC 2:</strong> Security controls for confidentiality and availability</li>
        </ul>

        <div class="report-footer">
            <div class="confidential">CONFIDENTIAL - FOR AUTHORIZED PERSONNEL ONLY</div>
            <p>
                <strong>Report Generated:</strong> $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") UTC<br>
                <strong>Assessment Type:</strong> Automated Security Scanning (Multi-Tool)<br>
                <strong>Coverage:</strong> Secrets, Dependencies, Infrastructure, Application Code, Runtime<br>
                <strong>Next Assessment:</strong> $(Get-Date (Get-Date).AddDays(7) -Format "yyyy-MM-dd")<br><br>
                This report was generated by automated security scanning tools. Manual validation is recommended for critical findings.<br>
                For questions or clarifications, contact the Security Engineering team.
            </p>
            <p style="margin-top: 15px; padding-top: 15px; border-top: 1px solid #ddd;">
                <a href='../guide/06-local-security-scans.md'>Scanning Documentation</a> | 
                <a href='https://owasp.org/www-project-top-ten/' target='_blank'>OWASP Top 10</a> |
                <a href='https://nvd.nist.gov/' target='_blank'>National Vulnerability Database</a>
            </p>
        </div>
    </div>
</body>
</html>
"@

# Save HTML report
$htmlReport | Out-File -FilePath "$reportsDir\security-report.html" -Encoding UTF8

Write-Host "" -ForegroundColor Green
Write-Host "Combined security report generated successfully!" -ForegroundColor Green
Write-Host "Report Location: $reportsDir\security-report.html" -ForegroundColor Cyan
Write-Host "" -ForegroundColor Green
Write-Host "SCAN SUMMARY" -ForegroundColor Cyan
Write-Host ("  Total Issues:       {0,4}" -f $totalIssues) -ForegroundColor $(if($totalIssues -eq 0){"Green"}else{"Yellow"})
Write-Host ("  Secrets:            {0,4}" -f $secretsCount) -ForegroundColor $(if($secretsCount -eq 0){"Green"}else{"Red"})
Write-Host ("  Vulnerabilities:    {0,4}" -f ($backendVulns + $frontendVulns)) -ForegroundColor $(if(($backendVulns + $frontendVulns) -eq 0){"Green"}else{"Yellow"})
Write-Host ("  IaC Issues:         {0,4}" -f ($checkovFailed + $tfsecIssues)) -ForegroundColor $(if(($checkovFailed + $tfsecIssues) -eq 0){"Green"}else{"Yellow"})
Write-Host ("  Code Issues:        {0,4}" -f $semgrepIssues) -ForegroundColor $(if($semgrepIssues -eq 0){"Green"}else{"Yellow"})
Write-Host ("  DAST Alerts:        {0,4}" -f $zapIssues) -ForegroundColor $(if($zapIssues -eq 0){"Green"}else{"Yellow"})

# Open report in browser
Write-Host "Opening report in browser..." -ForegroundColor Gray
Start-Process "$reportsDir\security-report.html"

