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

$expectedHeaders = @(
    @{ name = 'Content-Security-Policy'; impact = 'medium'; message = 'Missing Content-Security-Policy (CSP)  XSS risk, no script-src restriction' }
    @{ name = 'Strict-Transport-Security'; impact = 'medium'; message = 'Missing Strict-Transport-Security (HSTS)  MITM risk on first visit' }
    @{ name = 'X-Content-Type-Options'; impact = 'medium'; message = 'Missing X-Content-Type-Options: nosniff  MIME-sniffing risk' }
    @{ name = 'X-Frame-Options'; impact = 'low'; message = 'Missing X-Frame-Options  clickjacking risk' }
)

# Check middleware.ts/js for headers
$mwFiles = Get-ChildItem $resolvedDir -Recurse -File -Include 'middleware.ts', 'middleware.js' -ErrorAction SilentlyContinue
$allContent = ''

foreach ($mw in $mwFiles) {
    $relative = $mw.FullName.Substring($resolvedDir.Length + 1)
    foreach ($excl in $excludeDirs) {
        if ($relative -match "^$excl[\\/]") { return }
    }
    $allContent += (Get-Content $mw.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue) + "`n"
}

# Check next.config for headers
$configFiles = Get-ChildItem $resolvedDir -File -Include 'next.config.ts', 'next.config.js', 'next.config.mjs' -ErrorAction SilentlyContinue
foreach ($cf in $configFiles) {
    $allContent += (Get-Content $cf.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue) + "`n"
}

# Check vercel.json / netlify.toml
$platformConfigs = Get-ChildItem $resolvedDir -File -Include 'vercel.json', 'netlify.toml' -ErrorAction SilentlyContinue
foreach ($pc in $platformConfigs) {
    $allContent += (Get-Content $pc.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue) + "`n"
}

if ($allContent.Trim()) {
    $sourceLabel = if ($configFiles) { 'next.config' } elseif ($mwFiles) { 'middleware.ts' } else { 'config files' }

    foreach ($h in $expectedHeaders) {
        if ($allContent -notmatch $h.name) {
            $findings += @{
                impact = $h.impact
                type = 'headers'
                file = $sourceLabel
                line = 1
                message = $h.message
                snippet = "Header '$($h.name)' not found in any config or middleware"
                incident = '0% of vibe-coded apps tested by AppSec Santa (2025) set any security headers'
                confidence = 'proven'
            }
        }
    }
} else {
    # No config files at all
    foreach ($h in $expectedHeaders) {
        $findings += @{
            impact = $h.impact
            type = 'headers'
            file = 'next.config / middleware.ts'
            line = 1
            message = $h.message + "  no config or middleware file found"
            snippet = 'No next.config, middleware, vercel.json, or netlify.toml found'
            incident = '0% of vibe-coded apps set any security headers (AppSec Santa 2025)'
            confidence = 'proven'
        }
    }
}

$result = @{
    check = 'headers'
    status = if ($findings.Count -gt 0) { 'fail' } else { 'pass' }
    findings = $findings
    summary = @{ total = $findings.Count; can_fix = $true }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
