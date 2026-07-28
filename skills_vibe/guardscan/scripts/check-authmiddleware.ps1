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

# Check for middleware.ts/js with auth
$middlewarePath = $null
$mwFile = Get-ChildItem $resolvedDir -Recurse -File -Include 'middleware.ts', 'middleware.js' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($mwFile) {
    $middlewarePath = $mwFile.FullName
    $mwContent = Get-Content $middlewarePath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($mwContent -notmatch 'auth|token|session|verify|protect|getToken|getServerSession') {
        $findings += @{
            impact = 'medium'
            type = 'authmiddleware'
            file = 'middleware.ts'
            line = 1
            message = "middleware.ts exists but contains no auth checks  routes are unprotected"
            snippet = 'No auth, token, session, or verify call found in middleware'
            incident = 'Base44  authentication bypass due to missing route protection'
            confidence = 'proven'
        }
    }
} else {
    $findings += @{
        impact = 'medium'
        type = 'authmiddleware'
        file = 'middleware.ts'
        line = 1
        message = "No middleware.ts or middleware.js found  API routes have no central auth enforcement"
        snippet = 'No middleware file exists in project'
        incident = 'Base44  authentication bypass vulnerability across all platform apps'
        confidence = 'proven'
    }
}

# Check each app/api/ route for auth guards
$apiRoutes = Get-ChildItem $resolvedDir -Recurse -File -Include 'route.ts', 'route.js' -ErrorAction SilentlyContinue | Where-Object {
    $_.FullName -match '\\app\\api\\|/app/api/'
}

foreach ($route in $apiRoutes) {
    $relative = $route.FullName.Substring($resolvedDir.Length + 1)
    foreach ($excl in $excludeDirs) {
        if ($relative -match "^$excl[\\/]") { return }
    }

    $content = Get-Content $route.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    $hasAuth = $false
    $authPatterns = @('getToken', 'getServerSession', 'auth\s*\(', 'verifyToken', 'verifyAuth', 'protectRoute', 'requireAuth', 'middleware\s*\(')
    foreach ($ap in $authPatterns) {
        if ($content -match $ap) { $hasAuth = $true; break }
    }

    if (-not $hasAuth) {
        $lines = $content -split '\r?\n'
        $exportLine = 1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match 'export\s+(async\s+)?function\s+(GET|POST|PUT|DELETE|PATCH)') {
                $exportLine = $i + 1
                break
            }
        }

        $findings += @{
            impact = 'medium'
            type = 'authmiddleware'
            file = $relative
            line = $exportLine
            message = "API route handler without auth check  any user can call this endpoint"
            snippet = "No auth guard found in route handler"
            incident = 'Base44  unauthenticated access to protected API endpoints'
            confidence = 'proven'
        }
    }
}

$result = @{
    check = 'authmiddleware'
    status = if ($findings.Count -gt 0) { 'fail' } else { 'pass' }
    findings = $findings
    summary = @{ total = $findings.Count; can_fix = $false }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
