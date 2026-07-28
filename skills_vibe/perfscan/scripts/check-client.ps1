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
$excludeDirs = @('node_modules', '.next', 'dist', '.git')

Get-ChildItem $resolvedDir -Recurse -File -Include '*.tsx', '*.jsx' -ErrorAction SilentlyContinue | ForEach-Object {
    $relative = $_.FullName.Substring($resolvedDir.Length + 1)
    foreach ($excl in $excludeDirs) {
        if ($relative -match "^$excl[\\/]") { return }
    }

    $content = Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { return }

    if ($content -notmatch "'use client'|`"use client`"") { return }

    $hasClientFeature = $false
    $clientPatterns = @('useState', 'useEffect', 'useRef', 'useReducer', 'useContext',
                        'onClick', 'onChange', 'onSubmit', 'onMouse',
                        'window\.', 'document\.', 'localStorage', 'addEventListener')

    foreach ($pattern in $clientPatterns) {
        if ($content -match $pattern) {
            $hasClientFeature = $true
            break
        }
    }

    if (-not $hasClientFeature) {
        $lines = $content -split '\r?\n'
        $exportLine = 0
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match "export (default )?(function|const) ") {
                $exportLine = $i + 1
                break
            }
        }

        $findings += @{
            impact = 'medium'
            type = 'client'
            file = $relative
            line = $exportLine
            message = "Component marked 'use client' but uses no browser APIs or React hooks - consider Server Component"
            snippet = "'use client' at top of file, no useState/useEffect/event handlers found"
        }
    }
}

$result = @{
    check = 'client'
    status = if ($findings.Count -gt 0) { 'fail' } else { 'pass' }
    findings = $findings
    summary = @{ total = $findings.Count; can_fix = $true }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
