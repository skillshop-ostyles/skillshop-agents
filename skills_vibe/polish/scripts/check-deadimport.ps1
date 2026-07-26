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

Get-ChildItem $resolvedDir -Recurse -File -Include '*.ts', '*.tsx', '*.js', '*.jsx' -ErrorAction SilentlyContinue | ForEach-Object {
    $relative = $_.FullName.Substring($resolvedDir.Length + 1)
    foreach ($excl in $excludeDirs) {
        if ($relative -match "^$excl[\\/]") { return }
    }

    $content = Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { return }

    $lines = $content -split '\r?\n'
    $imports = @()

    # Extract import statements
    foreach ($line in $lines) {
        if ($line -match 'import\s+(\{[^}]+\}|\*+\s+as\s+\w+|\w+)\s+from') {
            $importBlock = $Matches[1]
            if ($importBlock -match '^\{(.+)\}$') {
                $names = $Matches[1] -split ',' | ForEach-Object { $_.Trim() -replace '\s+as\s+\w+', '' }
                foreach ($n in $names) {
                    if ($n -ne '') { $imports += @{ name = $n.Trim(); line = $_.LineNumber } }
                }
            } elseif ($importBlock -match '^\*\s+as\s+(\w+)') {
                $imports += @{ name = $Matches[1]; line = $_.LineNumber }
            } elseif ($importBlock -match '^(\w+)') {
                $imports += @{ name = $Matches[1]; line = $_.LineNumber }
            }
        }
    }

    # Check usage (skip imports that are only used in the import line itself)
    foreach ($imp in $imports) {
        $usageCount = 0
        $lineNum = 1
        foreach ($line in $lines) {
            if ($lineNum -ne $imp.line -and $line -match "\b$($imp.name)\b") {
                $usageCount++
            }
            $lineNum++
        }

        if ($usageCount -eq 0 -and $lines.Count -gt 1) {
            $findings += @{
                file = $relative
                line = $imp.line
                import = $imp.name
                message = "'$($imp.name)' imported but never used"
            }
        }
    }
}

$result = @{
    check = 'deadimport'
    status = if ($findings.Count -gt 0) { 'fail' } else { 'pass' }
    findings = $findings
    summary = @{ total = $findings.Count; can_fix = $true }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
