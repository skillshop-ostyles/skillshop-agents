[CmdletBinding()]
param(
    [string]$SpecDir,
    [string[]]$Files,
    [int]$MaxFileKB = 512
)

$ErrorActionPreference = 'Stop'

# git-independent, but the same Mojibake trap applies to any text file with
# umlauts under PowerShell 5.1 without explicit UTF8 output.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not $SpecDir -and (-not $Files -or $Files.Count -eq 0)) {
    Write-Error "Neither -SpecDir nor -Files specified."
    exit 1
}

function Test-ExcludedName($path) {
    $name = Split-Path $path -Leaf
    return ($name -match '(?i)secret|token|credential') -or ($name -match '(?i)^\.env')
}

$candidatePaths = @()
$root = $null

if ($SpecDir) {
    if (-not (Test-Path -LiteralPath $SpecDir)) {
        Write-Error "SpecDir does not exist: $SpecDir"
        exit 1
    }
    $root = (Resolve-Path -LiteralPath $SpecDir).Path
    $candidatePaths = @(
        Get-ChildItem -LiteralPath $SpecDir -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in '.md', '.txt' } |
            Select-Object -ExpandProperty FullName
    )
} else {
    foreach ($f in $Files) {
        if (-not (Test-Path -LiteralPath $f)) {
            Write-Error "File does not exist: $f"
            exit 1
        }
    }
    $candidatePaths = @($Files | ForEach-Object { (Resolve-Path -LiteralPath $_).Path })
}

$fileEntries = @()
$excludedEntries = @()

foreach ($p in $candidatePaths) {
    if (Test-ExcludedName $p) {
        $excludedEntries += $p
        continue
    }
    $item = Get-Item -LiteralPath $p
    $sizeKB = [Math]::Round($item.Length / 1KB, 1)
    $content = @(Get-Content -LiteralPath $p -ErrorAction SilentlyContinue)
    $lines = $content.Count
    $firstHeading = $null
    foreach ($line in $content) {
        if ($line -match '^#{1,6}\s+(.+)$') { $firstHeading = $matches[1].Trim(); break }
    }

    $fileEntries += [ordered]@{
        path         = $p
        sizeKB       = $sizeKB
        lines        = $lines
        firstHeading = $firstHeading
        oversized    = ($sizeKB -gt $MaxFileKB)
    }
}

$result = [ordered]@{
    root     = $root
    files    = $fileEntries
    excluded = $excludedEntries
    count    = $fileEntries.Count
}

Write-Output (ConvertTo-Json $result -Depth 6)

$oversizedCount = @($fileEntries | Where-Object { $_.oversized }).Count
Write-Output "`n=== SPEC-INTAKE ==="
Write-Output "  Files: $($fileEntries.Count)"
Write-Output "  Excluded (secrets-like): $($excludedEntries.Count)"
if ($oversizedCount -gt 0) { Write-Output "  Oversized (> $MaxFileKB KB): $oversizedCount" }
if ($fileEntries.Count -eq 0) { Write-Output "  No matching files found." }
