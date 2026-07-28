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

    $lines = Get-Content $_.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $lines) { return }

    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '\.map\s*\(') {
            $hasKey = $false
            $depth = 0
            $started = $false
            for ($j = $i; $j -lt [Math]::Min($i + 30, $lines.Count); $j++) {
                if ($lines[$j] -match '\bkey=') { $hasKey = $true; break }
                if ($lines[$j] -match '{') { $started = $true }
                if ($started) {
                    foreach ($c in $lines[$j].ToCharArray()) {
                        if ($c -eq '{') { $depth++ }
                        elseif ($c -eq '}') { $depth-- }
                    }
                    if ($depth -le 0) { break }
                }
            }
            if (-not $hasKey) {
                $findings += @{
                    impact = 'high'
                    type = 'keyprops'
                    file = $relative
                    line = $i + 1
                    snippet = $lines[$i].Trim().Substring(0, [Math]::Min(70, $lines[$i].Trim().Length))
                    message = '.map() without key= prop causes full list re-render on every change'
                }
            }
        }
    }
}

$result = @{
    check = 'keyprops'
    status = if ($findings.Count -gt 0) { 'fail' } else { 'pass' }
    findings = $findings
    summary = @{ total = $findings.Count; impact_high = $findings.Count; can_fix = $true }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
