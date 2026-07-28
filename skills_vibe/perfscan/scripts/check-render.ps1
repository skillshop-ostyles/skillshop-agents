[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ProjectDir
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$resolvedDir = Resolve-Path -LiteralPath $ProjectDir -ErrorAction Stop
$excludeDirs = @('node_modules', '.next', 'dist', '.git')
$findings = @()

Get-ChildItem $resolvedDir -Recurse -File -Include '*.tsx', '*.jsx' -ErrorAction SilentlyContinue | ForEach-Object {
    $relative = $_.FullName.Substring($resolvedDir.Length + 1)
    foreach ($excl in $excludeDirs) {
        if ($relative -match "^$excl[\\/]") { return }
    }

    $lines = Get-Content $_.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $lines) { return }

    $lineNum = 1
    $inReturnBlock = $false
    $depth = 0

    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        # Inline arrow function as component prop (creates new fn every render)
        if ($trimmed -match 'on\w+\s*=\{?\s*(?:\([^)]*\)|[^,{]+)\s*=>\s*\{?' -and $trimmed -notmatch 'useCallback|handle[A-Z]') {
            $findings += @{
                impact = 'low'
                type = 'render'
                file = $relative
                line = $lineNum
                message = 'Inline arrow function as prop - creates new closure on every render, breaks PureComponent/memo'
                snippet = $trimmed.Substring(0, [Math]::Min(70, $trimmed.Length))
            }
        }

        # Inline style={{}} object literal
        if ($trimmed -match 'style=\{?\s*\{\s*[a-z]+\s*:' -and $trimmed -notmatch 'className\s*=') {
            $findings += @{
                impact = 'low'
                type = 'render'
                file = $relative
                line = $lineNum
                message = 'Inline style object literal - new object every render, breaks React.memo comparison'
                snippet = $trimmed.Substring(0, [Math]::Min(70, $trimmed.Length))
            }
        }

        # .map() with inline component (creates new component class every render)
        if ($trimmed -match '\.map\(\s*(?:\([^)]*\)|\w+)\s*=>\s*<' -and $trimmed -notmatch 'key\s*=') {
            $findings += @{
                impact = 'low'
                type = 'render'
                file = $relative
                line = $lineNum
                message = '.map() with inline JSX without key= - new elements on every render, potential list unmount/remount'
                snippet = $trimmed.Substring(0, [Math]::Min(70, $trimmed.Length))
            }
        }

        $lineNum++
    }
}

$result = @{
    check = 'render'
    status = if ($findings.Count -gt 0) { 'fail' } else { 'pass' }
    findings = $findings
    summary = @{ total = $findings.Count; impact_low = $findings.Count; can_fix = $false }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
