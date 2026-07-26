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
$excludeDirs = @('node_modules', '.next', 'dist', '.git', 'coverage', '.vercel')

Get-ChildItem $resolvedDir -Recurse -File -Include '*.js', '*.jsx', '*.ts', '*.tsx', '*.json' -ErrorAction SilentlyContinue | ForEach-Object {
    $relative = $_.FullName.Substring($resolvedDir.Length + 1)
    foreach ($excl in $excludeDirs) {
        if ($relative -match "^$excl[\\/]") { return }
    }

    $content = Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { return }

    $lines = $content -split '\r?\n'
    $lineNum = 1
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -eq '' -or $trimmed -match '^\s*[/#*]') { $lineNum++; continue }

        # Hardcoded URLs (http/https)
        if ($trimmed -match "['\""](https?://[^'\""]{15,})['\""]") {
            $url = $Matches[1]
            $findings += @{
                type = 'hardcoded_url'
                file = $relative
                line = $lineNum
                value = $url.Substring(0, [Math]::Min(60, $url.Length))
                suggestion = 'Extract to env variable or config constant'
            }
            $lineNum++; continue
        }

        # Hardcoded ports
        if ($trimmed -match "['\""]:(\d{4,})[''\""]" -and $trimmed -notmatch 'version|"port"|"PORT"') {
            $port = $Matches[1]
            $findings += @{
                type = 'hardcoded_port'
                file = $relative
                line = $lineNum
                value = $port
                suggestion = 'Extract to env variable'
            }
            $lineNum++; continue
        }

        # Hardcoded API keys / tokens (qualified: value > 20 chars)
        if ($trimmed -match "['\""]([A-Za-z0-9_\-]{30,})[''\""]" -and $trimmed -notmatch 'version|sha|hash|uuid|npm|package') {
            $val = $Matches[1]
            $findings += @{
                type = 'hardcoded_secret_pattern'
                file = $relative
                line = $lineNum
                value = $val.Substring(0, [Math]::Min(40, $val.Length))
                suggestion = 'Move to .env or secrets manager'
            }
            $lineNum++; continue
        }

        $lineNum++
    }
}

$status = if ($findings.Count -gt 0) { 'fail' } else { 'pass' }
$result = @{
    check = 'magic'
    status = $status
    findings = $findings
    summary = @{ total = $findings.Count; can_fix = $false }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
