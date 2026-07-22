[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.cs,*.go,*.java,*.rb,*.php",
    [string]$Exclude = "",
    [int]$MinOccurrence = 2
)

$ErrorActionPreference = 'Stop'
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

# Heuristics for "magic values" worth auditing:
# - Numeric literals that look like constants (86400, 1024, 0.19, ...).
# - String literals matching common constant-y shapes (uppercase + underscores like PENDING_2; or quoted numerics like 'P3').
# Excludes:
# - 0, 1, -1, '', true, false, null (trivial).
# - Test files (configurable).
$trivialNumeric = @('-?1\b','-?0\b','0\.0','1\.0')
$trivialString = "^'$" , '^"$'

# Patterns to extract candidate literals.
$litPatterns = @(
    '(?<![\w\.])((?:[0-9]+(?:[\.,][0-9]+)?))',
    '"([A-Z][A-Z0-9_]{2,})"',
    "'([A-Z][A-Z0-9_]{2,})'"
)

# Build locations: list of {file, line, valueType, value}.
$allValues = @()
foreach ($ext in ($Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue | Where-Object {
        $fn = $_.FullName
        # Standard exclusions (path-segment aware).
        if ($fn -match '[\\/]node_modules[\\/]|[\\/]\.git[\\/]|[\\/]venv[\\/]|[\\/]__pycache__[\\/]|[\\/]dist[\\/]|[\\/]build[\\/]|[\\/]bin[\\/]|[\\/]obj[\\/]') { return $false }
        # Test files by name suffix.
        if ($fn -match '\.test\.|\.spec\.|_test\.py|Test\.cs|^spec[\./]') { return $false }
        # Allow fixtures under tests/fixtures.
        if ($fn -match '[\\/]fixtures[\\/]') { return $true }
        # Allow tests/fixtures paths.
        if ($fn -match '[\\/]tests[\\/]fixtures[\\/]') { return $true }
        # Exclude other tests/ top-level paths.
        if ($fn -match '[\\/]tests[\\/]') { return $false }
        return $true
    } | ForEach-Object {
        $fp = $_.FullName
        $content = Get-Content -LiteralPath $fp -Raw -ErrorAction SilentlyContinue
        if (-not $content) { return }
        $rel = $fp.Substring($ProjectDir.Length).TrimStart('\')
        $lines = $content -split "`n"
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            # Numeric literals (excluding trivial) - includes decimals like 0.19 leading-0.
            $numPat = "[^A-Za-z_" + [char]34 + [char]39 + "](\d+(?:[.,]\d+)?)(?![\w])"
            foreach ($m in [regex]::Matches($line, $numPat)) {
                $v = $m.Groups[1].Value
                # Skip pure single digits.
                if ($v -match '^[0-9]$') { continue }
                # Trivial pure ints under 100 (most are line/parameter indices, not magic).
                $isDecimal = $v -match '[.,]'
                if (-not $isDecimal) {
                    if ([int]$v -lt 100) { continue }
                }
                # Skip common false positives: years, percentages with 0.x where 0 is noise.
                if ($v -in '0','1','-1','24','60','3600') { continue }
                $ctxStart = [Math]::Max(0, $i - 2)
                $ctxEnd = [Math]::Min($lines.Count - 1, $i + 2)
                $allValues += @{
                    file = $rel
                    line = $i + 1
                    valueType = 'number'
                    value = $v
                    context = ($lines[$ctxStart..$ctxEnd] -join ' ')
                }
            }
            # String constants (uppercase + underscores).
            foreach ($m in [regex]::Matches($line, '"([A-Z][A-Z0-9_]{3,})"')) {
                $v = $m.Groups[1].Value
                $allValues += @{
                    file = $rel
                    line = $i + 1
                    valueType = 'string-constant'
                    value = $v
                    context = $line.Trim()
                }
            }
        }
    }
}

# Group by value, count occurrences.
$grouped = @{}
foreach ($v in $allValues) {
    $key = "$($v.valueType)|$($v.value)"
    if (-not $grouped.ContainsKey($key)) {
        $grouped[$key] = @{
            valueType = $v.valueType
            value = $v.value
            occurrences = @()
        }
    }
    $grouped[$key].occurrences += @{
        file = $v.file
        line = $v.line
        context = $v.context
    }
}

# Filter: only values occurring >= MinOccurrence times.
$filtered = @()
foreach ($key in $grouped.Keys) {
    $g = $grouped[$key]
    if ($g.occurrences.Count -ge $MinOccurrence) {
        # Git blame per first occurrence (if git repo).
        $firstOcc = $g.occurrences[0]
        $blame = $null
        if (Test-Path -LiteralPath (Join-Path $ProjectDir '.git') -PathType Any) {
            $blameOut = git -C $ProjectDir blame --line-porcelain (Join-Path $ProjectDir $firstOcc.file) -L "$($firstOcc.line),$($firstOcc.line)" 2>&1 | Out-String
            if ($blameOut -notmatch 'fatal:') {
                $authorLine = ($blameOut | Where-Object { $_ -match '^author ' } | Select-Object -First 1)
                $hashLine = ($blameOut | Where-Object { $_ -match '^[0-9a-f]{40} ' } | Select-Object -First 1)
                $summaryLine = ($blameOut | Where-Object { $_ -match '^summary ' } | Select-Object -First 1)
                if ($authorLine) {
                    $g.introducedBy = ($authorLine -replace '^author\s+', '')
                }
                if ($hashLine) {
                    $g.introducingCommit = ($hashLine -replace '^\S+\s+', '').Trim()
                    $gitShow = git -C $ProjectDir show -s --format=%s $g.introducingCommit 2>&1 | Out-String
                    if ($gitShow -notmatch 'fatal:') { $g.introducingSubject = $gitShow.Trim() }
                }
            }
        }
        $filtered += $g
    }
}

# Sort descending by occurrence count.
$filtered = $filtered | Sort-Object { $_.occurrences.Count } -Descending

Write-Output "=== Magic Value Harvest Complete ==="
Write-Output "  Files scanned: $(@($allValues | ForEach-Object { $_.file } | Select-Object -Unique).Count)"
Write-Output "  Distinct literals: $(@($grouped.Keys).Count)"
Write-Output "  Literals occurring >= $MinOccurrence times: $(@($filtered).Count)"

$result = @{
    values = $filtered
    counts = @{
        scannedFiles = (@($allValues | ForEach-Object { $_.file } | Select-Object -Unique)).Count
        totalLiterals = $allValues.Count
        distinctLiterals = @($grouped.Keys).Count
        recurringLiterals = @($filtered).Count
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
