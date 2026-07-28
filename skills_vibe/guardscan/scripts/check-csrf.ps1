[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ProjectDir
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$resolvedDir = Resolve-Path -LiteralPath $ProjectDir -ErrorAction Stop
$findings = @()
$excludeDirs = @('node_modules', '.next', 'dist', '.git', '.vercel')

Get-ChildItem $resolvedDir -Recurse -File -Include '*.tsx', '*.jsx', '*.ts', '*.js' -ErrorAction SilentlyContinue | ForEach-Object {
    $relative = $_.FullName.Substring($resolvedDir.Length + 1)
    foreach ($excl in $excludeDirs) {
        if ($relative -match "^$excl[\\/]") { return }
    }

    $lines = Get-Content $_.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $lines) { return }

    $lineNum = 1
    $hasCSRFToken = $false
    $hasMutation = $false
    $hasForm = $false
    $mutationLines = @()

    foreach ($line in $lines) {
        # Check for CSRF tokens / SameSite
        if ($line -match 'csrfToken|csrf_token|XSRF-TOKEN|csrf|sameSite|same_site') { $hasCSRFToken = $true }

        # Check for form with method POST/PUT/DELETE
        if ($line -match '<form' -and ($line -match 'method\s*=\s*["''](?:POST|PUT|DELETE)')) { $hasForm = $true; $mutationLines += $lineNum }

        # Check for fetch with POST/PUT/DELETE
        if ($line -match 'fetch\s*\(|axios\.(?:post|put|delete)|\.post\s*\(|\.put\s*\(|\.delete\s*\(') {
            $hasMutation = $true
            $mutationLines += $lineNum
        }

        $lineNum++
    }

    # If we found mutations/forms but no CSRF protection
    if (($hasForm -or $hasMutation) -and -not $hasCSRFToken) {
        foreach ($ml in $mutationLines) {
            $lineContent = $lines[$ml - 1].Trim()
            $findings += @{
                impact = 'medium'
                type = 'csrf'
                file = $relative
                line = $ml
                message = "Mutation endpoint without CSRF protection  no csrfToken or SameSite cookie found"
                snippet = $lineContent.Substring(0, [Math]::Min(70, $lineContent.Length))
                incident = '100% of vibe-coded apps tested by AppSec Santa (2025) had zero CSRF protection'
                confidence = 'likely'
            }
        }
    }
}

$result = @{
    check = 'csrf'
    status = if ($findings.Count -gt 0) { 'fail' } else { 'pass' }
    findings = $findings
    summary = @{ total = $findings.Count; can_fix = $true }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
