[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.cs,*.go,*.java,*.rb,*.php",
    [string]$Exclude = "",
    [int]$ContextLines = 3
)

$ErrorActionPreference = 'Stop'
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

# Signal patterns: each one is a hint that the code ASSUMES an invariant.
# The LLM translates each signal into an English-invariant sentence and
# judges whether the assumption is documented, asserted, or merely implicit.
$signalPatterns = @(
    @{ regex='(\w+)\[0\]'; kind='array-first-element' },
    @{ regex='(\w+)\.length\s*-\s*1'; kind='array-non-empty' },
    @{ regex='(\w+)\[(\w+)\.length\s*-\s*1\]'; kind='array-tail' },
    @{ regex='(\w+)\[(\w+)\.length'; kind='array-tail' },
    @{ regex='/[\s]*(\w+)\b'; kind='division-guarded' },  # Python operator: a / b
    @{ regex='\b(\w+)\s*/\s*(\w+)(?![\w])'; kind='division-b-by' },
    @{ regex='(\w+)\[(\w+)(?![\w])'; kind='subscript-guard' },
    @{ regex='JSON\.parse\s*\(\s*(\w+)'; kind='json-parse-input-format' },
    @{ regex='parseInt\s*\(\s*(\w+)\s*[,)]'; kind='parseInt-input-format' },
    @{ regex='parseFloat\s*\(\s*(\w+)'; kind='parseFloat-input-format' },
    @{ regex='await\s+(\w+)\.'; kind='async-state-readiness' },
    @{ regex='\.toLowerCase\(\s*\)\s*==?\s*["\x27][\w-]+["\x27]'; kind='case-normalization' },
    @{ regex='\.toUpperCase\(\s*\)\s*==?\s*["\x27][\w-]+["\x27]'; kind='case-normalization' }
)

# Order pattern: call A then call B; capture as ordered pair.
$signals = @()
$scannedFiles = 0

function Extract-FunctionBodies($content) {
    $bodies = @()
    $lines = $content -split "`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '^\s*(export\s+)?(public\s+|private\s+|protected\s+|static\s+)*(async\s+)?function\s+(\w+)([^()]*)\(([^)]*)\)\s*[:\{]?') {
            $name = $matches[3]
            $depth = 0; $end = $i; $seenb = $false; $endR = $false
            # find balanced braces from `:` or `{` position
            for ($j = $i; $j -lt $lines.Count -and -not $endR; $j++) {
                foreach ($ch in $lines[$j].ToCharArray()) {
                    if ($ch -eq '{') { $depth++; $seenb = $true }
                    elseif ($ch -eq '}') {
                        $depth--
                        if ($seenb -and $depth -eq 0) { $end = $j; $endR = $true; break }
                    }
                }
            }
            $bodies += @{
                name = $name
                startLine = $i + 1
                endLine = $end + 1
                body = ($lines[$i..$end] -join "`n")
            }
        }
    }
    return ,$bodies
}

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
        # Look for implicit invariant signals per line.
        for ($li = 0; $li -lt $lines.Count; $li++) {
            $ln = $lines[$li]
            foreach ($sp in $signalPatterns) {
                $m = [regex]::Match($ln, $sp.regex)
                if ($m.Success) {
                    $signals += @{
                        file = $rel
                        line = $li + 1
                        kind = $sp.kind
                        expression = $m.Value
                        subject = if ($m.Groups.Count -gt 1) { $m.Groups[1].Value } else { '' }
                        context = ($lines[([Math]::Max(0, $li - $ContextLines))..([Math]::Min($lines.Count - 1, $li + $ContextLines))] -join ' | ')
                    }
                }
            }
        }
    }
}

Write-Output "=== Invariant Scan Complete ==="
Write-Output "  Files scanned: $scannedFiles"
Write-Output "  Invariant signals: $($signals.Count)"

$result = @{
    signals = $signals
    counts = @{
        scannedFiles = $scannedFiles
        totalSignals = $signals.Count
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
