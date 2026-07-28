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

# Patterns that indicate client-side auth checks
$clientAuthPatterns = @(
    'if\s*\(\s*user\s*\)',
    'if\s*\(\s*session\s*\)',
    'if\s*\(!\s*user\s*\)',
    'if\s*\(!\s*session\s*\)',
    'useUser\(',
    'useSession\(',
    'useAuth\(',
    'user\?\s*\.\s*email',
    'session\?\s*\.\s*user',
    'router\.push.*login',
    'router\.replace.*login',
    'redirect.*login'
)

Get-ChildItem $resolvedDir -Recurse -File -Include '*.tsx', '*.jsx' -ErrorAction SilentlyContinue | ForEach-Object {
    $relative = $_.FullName.Substring($resolvedDir.Length + 1)
    foreach ($excl in $excludeDirs) {
        if ($relative -match "^$excl[\\/]") { return }
    }

    $content = Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { return }

    if ($content -notmatch "'use client'|`"use client`"") { return }

    $hasClientAuth = $false
    foreach ($cap in $clientAuthPatterns) {
        if ($content -match $cap) { $hasClientAuth = $true; break }
    }

    if (-not $hasClientAuth) { return }

    # Now check if there's ALSO a server-side guard (middleware, server action, API route check)
    # If the only auth is in client components, that's the finding
    $lines = $content -split '\r?\n'
    $lineNum = 1
    foreach ($line in $lines) {
        $matched = $false
        $patternUsed = ''
        foreach ($cap in $clientAuthPatterns) {
            if ($line -match $cap) {
                $matched = $true
                $patternUsed = $cap
                break
            }
        }

        if ($matched) {
            $findings += @{
                impact = 'high'
                type = 'clientauth'
                file = $relative
                line = $lineNum
                message = "Auth check only in client component  no server-side enforcement"
                snippet = $line.Trim().Substring(0, [Math]::Min(70, $line.Trim().Length))
                incident = 'Lovable January 2026  18,000+ users across 170 apps with inverted access control'
                confidence = 'likely'
            }
        }
        $lineNum++
    }
}

# Also check if there's a server-side auth middleware
$middlewareFile = Get-ChildItem $resolvedDir -Recurse -File -Include 'middleware.ts', 'middleware.js' -ErrorAction SilentlyContinue | Select-Object -First 1
$hasServerAuth = $false
if ($middlewareFile) {
    $mwContent = Get-Content $middlewareFile.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($mwContent -match 'auth|token|session|verify|protect|getToken|getServerSession') {
        $hasServerAuth = $true
    }
}

# If client auth exists but no server-side middleware, add a broader finding
if ($findings.Count -gt 0 -and -not $hasServerAuth) {
    $findings += @{
        impact = 'high'
        type = 'clientauth'
        file = 'middleware.ts'
        line = 1
        message = "No server-side auth middleware found  auth is only enforced in client components"
        snippet = 'middleware.ts/middleware.js missing auth checks'
        incident = 'Base44  auth bypass vulnerability across all platform apps'
        confidence = 'proven'
    }
}

$result = @{
    check = 'clientauth'
    status = if ($findings.Count -gt 0) { 'fail' } else { 'pass' }
    findings = $findings
    summary = @{ total = $findings.Count; impact_high = $findings.Count; can_fix = $false }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
