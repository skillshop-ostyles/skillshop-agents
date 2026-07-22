[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [Parameter(Mandatory = $true)]
    [string[]]$Symbols,

    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage'),

    [string[]]$Extensions = @('ts', 'tsx', 'js', 'jsx', 'py', 'cs', 'go', 'rs', 'java', 'php', 'rb', 'vue', 'sql', 'ps1')
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir existiert nicht: $ProjectDir"
    exit 1
}

$root = (Resolve-Path -LiteralPath $ProjectDir).Path
$excludeSet = @($Exclude | ForEach-Object { $_.ToLower() })
$extSet = @($Extensions | ForEach-Object { $_.TrimStart('.').ToLower() })

function Test-ExcludedPath($fullPath) {
    $rel = $fullPath.Substring($root.Length).TrimStart('\', '/')
    foreach ($part in ($rel -split '[\\/]')) {
        if ($excludeSet -contains $part.ToLower()) { return $true }
    }
    return $false
}

$allFiles = @(
    Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
        Where-Object { -not (Test-ExcludedPath $_.FullName) }
)
$scannedFiles = $allFiles.Count
$CAP = 200

$symbolHits = @{}
$symbolCapped = @{}
$patterns = @{}
foreach ($sym in $Symbols) {
    $symbolHits[$sym] = New-Object System.Collections.Generic.List[object]
    $symbolCapped[$sym] = $false
    $patterns[$sym] = "\b$([regex]::Escape($sym))\b"
}

foreach ($f in $allFiles) {
    $remaining = @($Symbols | Where-Object { -not $symbolCapped[$_] })
    if ($remaining.Count -eq 0) { break }

    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lineNum = 0
    foreach ($line in (Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue)) {
        $lineNum++
        foreach ($sym in $remaining) {
            if ($line -cmatch $patterns[$sym]) {
                $trimmed = $line.Trim()
                if ($trimmed.Length -gt 200) { $trimmed = $trimmed.Substring(0, 200) }
                $symbolHits[$sym].Add([ordered]@{ file = $relPath; line = $lineNum; text = $trimmed })
                if ($symbolHits[$sym].Count -ge $CAP) { $symbolCapped[$sym] = $true }
            }
        }
    }
}

# foreach-als-Ausdruck statt "$arr += [ordered]@{...}": Letzteres loest bei
# verschachtelten Collection-Ausdruecken innerhalb eines [ordered]-Hashtable-Literals
# unter PowerShell 5.1 einen Dynamic-Binder-Bug aus ("Argumenttypen stimmen nicht
# ueberein", PSEnumerableBinder.MaybeDebase) - beim Testen gefunden.
$symbolResults = @(
    foreach ($sym in $Symbols) {
        [ordered]@{
            symbol   = $sym
            hits     = $symbolHits[$sym].ToArray()
            hitCount = $symbolHits[$sym].Count
            capped   = $symbolCapped[$sym]
        }
    }
)

$result = [ordered]@{
    symbols      = $symbolResults
    scannedFiles = $scannedFiles
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== REF-SCAN ==="
Write-Output "  Gescannte Dateien: $scannedFiles"
foreach ($sr in $symbolResults) {
    Write-Output "  Symbol '$($sr.symbol)': $($sr.hitCount) Treffer$(if ($sr.capped) { ' (gekappt bei 200)' })"
}
