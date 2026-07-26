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

Get-ChildItem $resolvedDir -Recurse -File -Include '*.ts', '*.tsx' -ErrorAction SilentlyContinue | ForEach-Object {
    $relative = $_.FullName.Substring($resolvedDir.Length + 1)
    foreach ($excl in $excludeDirs) {
        if ($relative -match "^$excl[\\/]") { return }
    }

    $content = Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { return }

    $lines = $content -split '\r?\n'
    $lineNum = 1
    foreach ($line in $lines) {
        $matched = $false
        $context = $null

        if ($line -match ':\s*any(?:\s*[,);\]]|$)') {
            $matched = $true; $context = 'type annotation'
        } elseif ($line -match 'as\s+any(?:\s*[,);\]}]|$)') {
            $matched = $true; $context = 'type cast'
        } elseif ($line -match '<any,|<any\s') {
            $matched = $true; $context = 'generic parameter'
        } elseif ($line -match 'as\s+const\s+as\s+any') {
            $matched = $true; $context = 'double cast'
        }

        if ($matched) {
            $findings += @{
                file = $relative
                line = $lineNum
                snippet = $line.Trim().Substring(0, [Math]::Min(80, $line.Trim().Length))
                context = $context
            }
        }
        $lineNum++
    }
}

$result = @{
    check = 'anytype'
    status = if ($findings.Count -gt 0) { 'fail' } else { 'pass' }
    findings = $findings
    summary = @{ total = $findings.Count; can_fix = $false }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
