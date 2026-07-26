[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.cs,*.go,*.java,*.rb,*.php",
    [string]$Exclude = "",

    # Default pairs of competing patterns the collector will screen for.
    [string]$CustomPairs = ""
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

# Each pair: two competing patterns that solve the same problem domain. The
# collector counts how many files use each side and reads git history for the
# first/last commit touching each side.
$defaultPairs = @(
    @{ name='HTTP_CLIENT';  sideA='axios';         sideB='fetch';          kind='http' },
    @{ name='HTTP_CLIENT';  sideA='got';           sideB='fetch';          kind='http' },
    @{ name='HTTP_CLIENT';  sideA='request';       sideB='fetch';          kind='http' },
    @{ name='DATE_LIB';     sideA='moment';        sideB='date-fns';       kind='date' },
    @{ name='DATE_LIB';     sideA='moment';        sideB='dayjs';          kind='date' },
    @{ name='DATE_LIB';     sideA='luxon';         sideB='dayjs';          kind='date' },
    @{ name='TEST';         sideA='jest';          sideB='vitest';         kind='test' },
    @{ name='TEST';         sideA='mocha';         sideB='jest';           kind='test' },
    @{ name='PROMISE';      sideA='\.then\s*\(';   sideB='\basync\s+';     kind='promise' },
    @{ name='MODULE';       sideA='require\s*\(';  sideB='\bimport\s+';    kind='module' },
    @{ name='STATE_LIB';    sideA='redux';         sideB='zustand';        kind='state' },
    @{ name='STATE_LIB';    sideA='redux';         sideB='mobx';           kind='state' },
    @{ name='VALIDATION';   sideA='joi';           sideB='zod';            kind='validation' },
    @{ name='VALIDATION';   sideA='ajv';           sideB='zod';            kind='validation' },
    @{ name='FORM';         sideA='formik';        sideB='react-hook-form'; kind='form' },
    @{ name='STYLE';        sideA='styled-components'; sideB='emotion';     kind='style' },
    @{ name='STYLE';        sideA='sass';          sideB='tailwind';       kind='style' },
    @{ name='LOGGER';       sideA='winston';       sideB='pino';           kind='logger' }
)

$pairs = @()
if ($CustomPairs) {
    foreach ($cp in ($CustomPairs -split ';')) {
        $parts = $cp -split ','
        if ($parts.Count -ge 2) {
            $pairs += @{ name='CUSTOM'; sideA=$parts[0].Trim(); sideB=$parts[1].Trim(); kind='custom' }
        }
    }
} else {
    $pairs = $defaultPairs
}

# Group occurrences by file per pair.
$occurrences = @{}
foreach ($pair in $pairs) {
    $key = "$($pair.name)|$($pair.kind)|$($pair.sideA)|$($pair.sideB)"
    $occurrences[$key] = @{
        kind = $pair.kind
        name = $pair.name
        sideA = $pair.sideA
        sideB = $pair.sideB
        filesA = @()
        filesB = @()
    }
}

$scannedFiles = 0

# Convert extensions param into array.
$exts = @($Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

foreach ($ext in $exts) {
    Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch 'node_modules|\.git|venv|bin|obj|__pycache__|dist|build'
    } | ForEach-Object {
        $fp = $_.FullName
        $scannedFiles++
        $content = Get-Content -LiteralPath $fp -Raw -ErrorAction SilentlyContinue
        if (-not $content) { return }
        $rel = $fp.Substring($ProjectDir.Length).TrimStart('\')
        foreach ($key in $occurrences.Keys) {
            $pair = $occurrences[$key]
            $patA = $pair.sideA
            $patB = $pair.sideB
            # If pattern contains regex meta, use as-is; else use word-boundary literal match.
            $isRegexA = $patA -match '[\\\^\$\.\|\?\*\+\(\)\[\]\{\}]'
            if ($isRegexA) { $rA = $content -match $patA } else { $rA = $content -match ("(?<![\w])" + [regex]::Escape($patA) + "(?![\w])") }
            $isRegexB = $patB -match '[\\\^\$\.\|\?\*\+\(\)\[\]\{\}]'
            if ($isRegexB) { $rB = $content -match $patB } else { $rB = $content -match ("(?<![\w])" + [regex]::Escape($patB) + "(?![\w])") }
            if ($rA) { if ($rel -notin $pair.filesA) { $pair.filesA += $rel } }
            if ($rB) { if ($rel -notin $pair.filesB) { $pair.filesB += $rel } }
        }
    }
}

# Compute git timeline per side (only if ProjectDir is in a git repo).
$inGit = $false
if (Test-Path -LiteralPath (Join-Path $ProjectDir '.git') -PathType Any) { $inGit = $true }

# Project-level schisms: emit only pairs where both sides have files.
$schisms = @()
foreach ($key in $occurrences.Keys) {
    $pair = $occurrences[$key]
    if ($pair.filesA.Count -gt 0 -and $pair.filesB.Count -gt 0) {
        $schism = @{
            patternName = $pair.name
            kind = $pair.kind
            sideA = $pair.sideA
            sideB = $pair.sideB
            filesA = $pair.filesA
            filesB = $pair.filesB
            countA = $pair.filesA.Count
            countB = $pair.filesB.Count
            totalA = $pair.filesA.Count + $pair.filesB.Count
        }
        if ($inGit) {
            # First/last commit per side, using log of any file containing the pattern.
            $firstA = $null; $lastA = $null
            foreach ($f in ($pair.filesA | Select-Object -First 5)) {
                $resA = git -C $ProjectDir log --follow --format=%H -- $f 2>&1 | Out-String
                if ($resA -notmatch 'fatal:' -and $resA.Trim()) {
                    $lines = ($resA.Trim() -split "`n")
                    if (-not $firstA -or $lines[-1] -lt $firstA) { $firstA = $lines[-1] }
                    if (-not $lastA -or $lines[0] -gt $lastA) { $lastA = $lines[0] }
                }
            }
            $firstB = $null; $lastB = $null
            foreach ($f in ($pair.filesB | Select-Object -First 5)) {
                $resB = git -C $ProjectDir log --follow --format=%H -- $f 2>&1 | Out-String
                if ($resB -notmatch 'fatal:' -and $resB.Trim()) {
                    $lines = ($resB.Trim() -split "`n")
                    if (-not $firstB -or $lines[-1] -lt $firstB) { $firstB = $lines[-1] }
                    if (-not $lastB -or $lines[0] -gt $lastB) { $lastB = $lines[0] }
                }
            }
            $schism.firstA = $firstA
            $schism.lastA = $lastA
            $schism.firstB = $firstB
            $schism.lastB = $lastB
        }
        $schisms += $schism
    }
}

$result = @{
    schisms = $schisms
    counts = @{
        scannedFiles = $scannedFiles
        pairsChecked = $pairs.Count
        schismsFound = @($schisms | Where-Object { $_.countA -gt 0 -and $_.countB -gt 0 }).Count
    }
}

Write-Output "=== Migration Limbo Scan Complete ==="
Write-Output "  Files scanned: $scannedFiles"
Write-Output "  Pattern pairs checked: $($pairs.Count)"
Write-Output "  Schisms found (both sides used): $($result.counts.schismsFound)"
foreach ($s in $schisms) {
    Write-Output "  $($s.patternName): $($s.countA)x $($s.sideA) vs. $($s.countB)x $($s.sideB)"
}

Write-Output ($result | ConvertTo-Json -Depth 8)
exit 0
