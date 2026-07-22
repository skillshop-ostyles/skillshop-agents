[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('ts', 'tsx', 'js', 'jsx', 'py', 'cs', 'go', 'rs', 'java', 'php', 'rb', 'vue', 'ps1'),
    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage'),
    [string[]]$EntryPointPatterns = @('index', 'main', 'app', 'program', '*.test', '*.spec', '*.config')
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

function Test-EntryPoint($baseName) {
    foreach ($p in $EntryPointPatterns) {
        if ($baseName -like $p) { return $true }
    }
    return $false
}

$allFiles = @(
    Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
        Where-Object { -not (Test-ExcludedPath $_.FullName) }
)
$scannedFiles = $allFiles.Count

# Best-effort, sprachfamilienuebergreifend (Grep-Niveau, Simplicity First - siehe
# Sprint 03/04 fuer dieselbe Design-Entscheidung).
$exportPatterns = @(
    'export\s+(?:async\s+)?(?:function|const|class|interface|type)\s+(\w+)',
    '\bpublic\s+(?:static\s+)?[\w<>\[\],\.\s]+?\s+(\w+)\s*\(',
    '^\s*def\s+(\w+)\s*\(',
    '\bfunc\s+(?:\([^)]*\)\s+)?(\w+)\s*\('
)

# file -> content (einmal gelesen, fuer Export-Extraktion UND Referenz-Zaehlung wiederverwendet)
$fileContents = @{}
$fileRelPaths = @{}
foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $fileRelPaths[$f.FullName] = $relPath
    $fileContents[$f.FullName] = [string]::Join("`n", (Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue))
}

# --- Export-Inventar ---
$exportsSeen = [ordered]@{}   # key "file|symbol" -> [ordered]@{file=;line=;symbol=}
foreach ($f in $allFiles) {
    $relPath = $fileRelPaths[$f.FullName]
    $lines = @(Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue)
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = [string]$lines[$i]
        foreach ($pat in $exportPatterns) {
            $m = [regex]::Match($line, $pat)
            if ($m.Success) {
                $symbol = $m.Groups[1].Value
                $key = "$relPath|$symbol"
                if (-not $exportsSeen.Contains($key)) {
                    $exportsSeen[$key] = [ordered]@{ file = $relPath; line = ($i + 1); symbol = $symbol }
                }
            }
        }
    }
}

# --- Referenz-Zaehlung (Wortgrenze, ANDERE Dateien) ---
$symbolCandidates = @(
    foreach ($entry in $exportsSeen.Values) {
        $pattern = "\b$([regex]::Escape($entry.symbol))\b"
        $externalRefs = 0
        foreach ($f in $allFiles) {
            $relPath = $fileRelPaths[$f.FullName]
            if ($relPath -eq $entry.file) { continue }
            $refHits = [regex]::Matches($fileContents[$f.FullName], $pattern)
            $externalRefs += $refHits.Count
        }
        if ($externalRefs -eq 0) {
            [ordered]@{ file = $entry.file; line = $entry.line; symbol = $entry.symbol; externalRefs = 0 }
        }
    }
)

# --- Datei-Kandidaten: von keiner anderen Datei referenziert, kein Entry-Point-Muster ---
$fileCandidates = @(
    foreach ($f in $allFiles) {
        $relPath = $fileRelPaths[$f.FullName]
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($f.Name)
        if (Test-EntryPoint $baseName) { continue }
        $pattern = "\b$([regex]::Escape($baseName))\b"
        $referencedBy = 0
        foreach ($other in $allFiles) {
            if ($other.FullName -eq $f.FullName) { continue }
            $refHits = [regex]::Matches($fileContents[$other.FullName], $pattern)
            $referencedBy += $refHits.Count
        }
        if ($referencedBy -eq 0) {
            [ordered]@{ file = $relPath; referencedBy = 0; isEntryPointPattern = $false }
        }
    }
)

$result = [ordered]@{
    symbolCandidates = $symbolCandidates
    fileCandidates   = $fileCandidates
    scannedFiles     = $scannedFiles
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== REACHABILITY ==="
Write-Output "  Gescannte Dateien: $scannedFiles"
Write-Output "  Symbol-Kandidaten (0 externe Referenzen): $($symbolCandidates.Count)"
Write-Output "  Datei-Kandidaten (nie referenziert, kein Entry-Point): $($fileCandidates.Count)"
