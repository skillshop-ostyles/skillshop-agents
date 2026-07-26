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
$excludeDirs = @('node_modules', '.next', 'dist', '.git', 'coverage')

Get-ChildItem $resolvedDir -Recurse -File -Include '*.js', '*.jsx', '*.ts', '*.tsx' -ErrorAction SilentlyContinue | ForEach-Object {
    $relative = $_.FullName.Substring($resolvedDir.Length + 1)
    foreach ($excl in $excludeDirs) {
        if ($relative -match "^$excl[\\/]") { return }
    }

    $content = Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { return }

    $lines = $content -split '\r?\n'
    $lineNum = 1
    foreach ($line in $lines) {
        if ($line -match 'console\.(log|warn|error)\s*\(' -and $line -notmatch 'logger|log\.') {
            $findings += @{
                file = $relative
                line = $lineNum
                snippet = $line.Trim()
                method = $Matches[1]
            }
        }
        $lineNum++
    }
}

$result = @{
    check = 'consolelog'
    status = if ($findings.Count -gt 0) { 'fail' } else { 'pass' }
    findings = $findings
    summary = @{ total = $findings.Count; can_fix = $true }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
