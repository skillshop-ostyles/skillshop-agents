[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ProjectDir
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$resolvedDir = Resolve-Path -LiteralPath $ProjectDir -ErrorAction Stop
$excludeDirs = @('node_modules', '.next', 'dist', '.git', '.vercel')
$fileStats = @()

Get-ChildItem $resolvedDir -Recurse -File -Include '*.ts', '*.tsx', '*.js', '*.jsx' -ErrorAction SilentlyContinue | ForEach-Object {
    $relative = $_.FullName.Substring($resolvedDir.Length + 1)
    foreach ($excl in $excludeDirs) {
        if ($relative -match "^$excl[\\/]") { return }
    }

    $lines = Get-Content $_.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $lines) { return }

    $importCount = 0
    $exportCount = 0
    $componentCount = 0
    $hasLazyImport = $false

    foreach ($line in $lines) {
        if ($line -match 'import\s+') { $importCount++ }
        if ($line -match 'export\s+') { $exportCount++ }
        if ($line -match 'function\s+\w+|const\s+\w+\s*=') { $componentCount++ }
        if ($line -match 'lazy\(|dynamic\(|React\.lazy') { $hasLazyImport = $true }
    }

    if ($lines.Count -gt 150 -or $importCount -gt 30) {
        $fileStats += @{
            path = $relative
            lines = $lines.Count
            imports = $importCount
            exports = $exportCount
            components = $componentCount
            has_lazy = $hasLazyImport
        }
    }
}

$findings = @()
foreach ($fs in $fileStats) {
    if ($fs.lines -gt 250 -and -not $fs.has_lazy) {
        $findings += @{
            impact = 'medium'
            type = 'bundle'
            file = $fs.path
            lines_count = $fs.lines
            message = "$($fs.path) has $($fs.lines) lines and $($fs.imports) imports without lazy loading - split into smaller chunks"
        }
    } elseif ($fs.lines -gt 150 -and $fs.imports -gt 30) {
        $findings += @{
            impact = 'medium'
            type = 'bundle'
            file = $fs.path
            lines_count = $fs.lines
            message = "$($fs.path) has $($fs.imports) imports - consider lazy loading or barrel file"
        }
    } elseif ($fs.lines -gt 200 -and $fs.components -gt 3) {
        $findings += @{
            impact = 'low'
            type = 'bundle'
            file = $fs.path
            lines_count = $fs.lines
            message = "$($fs.path) has $($fs.components) components in one file - consider splitting"
        }
    }
}

$result = @{
    check = 'bundle'
    status = if ($findings.Count -gt 0) { 'fail' } else { 'pass' }
    findings = $findings
    raw = @{ files_analyzed = $fileStats.Count }
    summary = @{ total = $findings.Count; can_fix = $false }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
