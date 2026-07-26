[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.cs,*.go,*.java,*.rb,*.php",
    [string]$Exclude = "",
    [int]$ContextLines = 3
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

# Patterns for guards we capture.
# Single-line:
$guardPatterns = @(
    @{ regex='if\s*\(\s*(\w+)\s*===\s*null\s*\)'; kind='null-check' },
    @{ regex='if\s*\(\s*!\s*(\w+)\s*\)'; kind='null-check' },
    @{ regex='if\s*\(\s*(\w+)\s*==\s*undefined\s*\)'; kind='null-check' },
    @{ regex='if\s*\(\s*typeof\s+(\w+)\s*!==?\s*["\x27]undefined["\x27]\s*\)'; kind='type-check' },
    @{ regex='if\s*\(\s*(\w+)\.length\s*[<>=]+\s*0\s*\)'; kind='empty-check' },
    @{ regex='if\s*\(\s*(\w+)\s*==\s*null\s*\|\|\s*\1\s*==\s*undefined\s*\)'; kind='null-check' },
    @{ regex='if\s*\(\s*(\w+)\.\w+\s*\|\|\s*[\w ,]+\s*\)\s*'; kind='truthy-check' },
    @{ regex='try\s*\{'; kind='try-catch' },
    @{ regex='catch\s*\(\s*(\w+)\s*\)'; kind='catch' },
    @{ regex='if\s*\(\s*(\w+)\s+instanceof\s+\w+\s*\)'; kind='instanceof-check' },
    @{ regex='Number\.isInteger\s*\(\s*(\w+)\s*\)'; kind='integer-check' },
    @{ regex='Number\.isNaN\s*\(\s*(\w+)\s*\)'; kind='nan-check' },
    @{ regex='typeof\s+(\w+)\s*===?\s*["\x27]function["\x27]'; kind='function-check' },
    @{ regex='Array\.isArray\s*\(\s*(\w+)\s*\)'; kind='array-check' }
)

$guards = @()
$scannedFiles = 0

foreach ($ext in ($Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    $items = Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue
    foreach ($i in $items) {
        $fn = $i.FullName
        $accept = $true
        if ($fn -match '[\\/]node_modules[\\/]|[\\/]\.git[\\/]|[\\/]venv[\\/]|[\\/]__pycache__[\\/]|[\\/]dist[\\/]|[\\/]build[\\/]|[\\/]bin[\\/]|[\\/]obj[\\/]') { $accept = $false }
        if ($accept -and ($fn -match '\.test\.|\.spec\.|_test\.py|Test\.cs')) { $accept = $false }
        if ($accept -and ($fn -match '[\\/]fixtures[\\/]')) { $accept = $true }
        if ($accept -and ($fn -match '[\\/]tests[\\/]fixtures[\\/]')) { $accept = $true }
        if ($accept -and ($fn -match '[\\/]tests[\\/]') -and ($fn -notmatch '[\\/]fixtures[\\/]')) { $accept = $false }
        if (-not $accept) { continue }
        $scannedFiles++
        $content = Get-Content -LiteralPath $fn -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $rel = $fn.Substring($ProjectDir.Length).TrimStart('\')
        $lines = $content -split "`n"
        for ($li = 0; $li -lt $lines.Count; $li++) {
            $ln = $lines[$li]
            foreach ($g in $guardPatterns) {
                $m = [regex]::Match($ln, $g.regex)
                if ($m.Success) {
                    $guards += @{
                        file = $rel
                        line = $li + 1
                        kind = $g.kind
                        subject = $m.Groups[1].Value
                        expression = $m.Value
                        context = ($lines[([Math]::Max(0, $li - $ContextLines))..([Math]::Min($lines.Count - 1, $li + $ContextLines))] -join " | ")
                    }
                }
            }
        }
    }
}

# External input heuristics: function args that look like request/input/argv.
$externalInputPattern = '^(\s*)((function\s+(\w+))?\s*(\w+)?(\s*\w+\s*)?\(.*\b(req|request|argv|body|query|params|input|stdin|argv)\b)'
# This is a rough heuristic; deeper tooling would do taint tracing.

Write-Output "=== Paranoia Profile Complete ==="
Write-Output "  Files scanned: $scannedFiles"
Write-Output "  Guards detected: $($guards.Count)"

$result = @{
    guards = $guards
    counts = @{
        scannedFiles = $scannedFiles
        totalGuards = $guards.Count
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
