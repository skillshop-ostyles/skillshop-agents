[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('ts', 'tsx', 'js', 'jsx', 'py', 'cs', 'go', 'rs', 'java', 'php', 'rb', 'vue', 'sql', 'ps1'),
    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage'),
    [int]$MaxCandidates = 1000
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir does not exist: $ProjectDir"
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
    $leaf = Split-Path $fullPath -Leaf
    if ($leaf -match '(?i)\.min\.' -or $leaf -match '(?i)generated') { return $true }
    return $false
}

function Get-Context($lines, $idx) {
    # [string]-Cast: Get-Content lines carry PowerShell-ETS metadata (PSPath etc.)
    # on the object, which ConvertTo-Json would otherwise serialize instead of just the line content.
    $result = @()
    for ($j = $idx - 2; $j -lt $idx; $j++) { if ($j -ge 0) { $result += [string]$lines[$j] } }
    for ($j = $idx + 1; $j -le $idx + 2; $j++) { if ($j -lt $lines.Count) { $result += [string]$lines[$j] } }
    return $result
}

$allFiles = @(
    Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
        Where-Object { -not (Test-ExcludedPath $_.FullName) }
)
$scannedFiles = $allFiles.Count

# 6 pattern families (grep-level, simplicity first - see sprint 03 for the same
# design decision in ref-scan.ps1).
$categoryPatterns = [ordered]@{
    comparison  = '[<>]=?\s*\d|={2,3}\s*[''"\d]'
    constant    = '(?i)\b(const|final|static|readonly)\b.*\d|^\s*[A-Z_]{3,}\s*='
    regex       = '(?i)\bregex\b|\bpattern\b|\.match\(|/[^/\r\n]{1,80}/[a-zA-Z]{0,2}\b'
    validation  = '(?i)\b(valid|check|verify|ensure|require|assert)\w*\s*\('
    calculation = '(?i)\b(calc|compute|total|sum|rate|price|tax|fee|discount)\w*'
    status      = '(?i)\b(status|state)\b.*={2,3}\s*[''"]'
}

$countsByCategory = [ordered]@{}
foreach ($k in $categoryPatterns.Keys) { $countsByCategory[$k] = 0 }

$candidateList = New-Object System.Collections.Generic.List[object]
$truncated = $false

foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = @(Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue)
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $cats = @($categoryPatterns.Keys | Where-Object { $line -match $categoryPatterns[$_] })
        if ($cats.Count -eq 0) { continue }
        foreach ($c in $cats) { $countsByCategory[$c] += 1 }

        if ($candidateList.Count -lt $MaxCandidates) {
            $candidateList.Add([ordered]@{
                    file     = $relPath
                    line     = $i + 1
                    category = $cats
                    text     = $line.Trim()
                    context  = @(Get-Context $lines $i)
                })
        } else {
            $truncated = $true
        }
    }
}

$result = [ordered]@{
    candidates       = $candidateList.ToArray()
    countsByCategory = $countsByCategory
    truncated        = $truncated
    scannedFiles     = $scannedFiles
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== RULE-CANDIDATES ==="
Write-Output "  Scanned files: $scannedFiles"
Write-Output "  Total candidates: $($candidateList.Count)$(if ($truncated) { " (truncated to $MaxCandidates)" })"
foreach ($k in $countsByCategory.Keys) {
    Write-Output "    $k`: $($countsByCategory[$k])"
}
