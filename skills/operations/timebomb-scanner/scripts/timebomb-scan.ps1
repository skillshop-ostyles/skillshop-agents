[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('ts', 'tsx', 'js', 'jsx', 'py', 'cs', 'go', 'rs', 'java', 'php', 'rb', 'vue', 'sql', 'ps1', 'json', 'yaml', 'yml', 'toml', 'ini', 'xml', 'config'),
    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage'),
    [int]$ProvisionalAgeDays = 365
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
    return $false
}

function Test-ChangelogPath($fullPath) {
    $leaf = Split-Path $fullPath -Leaf
    if ($leaf -match '(?i)^(CHANGELOG|HISTORY)') { return $true }
    $rel = $fullPath.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    if ($rel -match '(?i)(^|/)docs/') { return $true }
    return $false
}

$gitAvailable = $false
$repoCheck = & git -C $root rev-parse -is-inside-work-tree 2>$null
if ($LASTEXITCODE -eq 0 -and $repoCheck -eq 'true') { $gitAvailable = $true }

$allFiles = @(
    Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
        Where-Object { -not (Test-ExcludedPath $_.FullName) }
)
$scannedFiles = $allFiles.Count

$isoDateRegex = '\d{4}-\d{2}-\d{2}'
# Broader than the comparison/assignment form mentioned in the sprint file
# ([=<>]\s*['"]?20\d{2}): the test plan explicitly requires that even a
# standalone copyright year is found, so the LLM analysis can actively
# discard it as a false positive (Â§ 6.1) - a pure comparison regex
# would never match "Copyright 2019". Hence: every word-boundary-accurate
# year 2015-2099, not only in comparison/assignment context.
$standaloneYearRegex = '\b20(1[5-9]|[2-9]\d)\b'
$timestampContextRegex = '(?i)\b(time|date|expir|epoch)\w*\b'
$unixTsRegex = '\b[12]\d{9}\b'
$expiryKeywordRegex = '(?i)\b(expir\w*|deadline|valid.?until|g[ue]ltig\w*|ablauf\w*|sunset|end.?of.?life|eol)\b'
$provisionalRegex = "(?i)\b(TODO|FIXME|HACK|XXX|temp(orary|or.r)?|provisorisch\w*|workaround|quick.?fix|remove\s+(this|later|me))\b"
$int32TimeRegex = '(?i)(\bint(32)?\b[\s\w\[\]]*(time|timestamp))|((time|timestamp)\w*[\s:=]*\bint(32)?\b)|(\b2038\b)'

$findings = New-Object System.Collections.Generic.List[object]
$countsByClass = [ordered]@{ 'date-literal' = 0; 'expiry-keyword' = 0; 'provisional' = 0; 'int32-time' = 0 }

foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $isChangelog = Test-ChangelogPath $f.FullName
    $lines = @(Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue)

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = [string]$lines[$i]
        $lineNum = $i + 1

        # -- 1. Date literals (not in changelog/doc files) --
        if (-not $isChangelog) {
            $isoMatch = [regex]::Match($line, $isoDateRegex)
            $yearMatch = [regex]::Match($line, $standaloneYearRegex)
            $unixMatch = ($line -match $unixTsRegex) -and ($line -match $timestampContextRegex)
            if ($isoMatch.Success -or $yearMatch.Success -or $unixMatch) {
                $dateFound = $null
                if ($isoMatch.Success) { $dateFound = $isoMatch.Value }
                elseif ($yearMatch.Success) { $dateFound = $yearMatch.Value }
                $countsByClass['date-literal'] += 1
                $findings.Add([ordered]@{
                        class = 'date-literal'; file = $relPath; line = $lineNum; text = $line.Trim(); date = $dateFound
                    })
            }
        }

        # -- 2. Expiry keywords --
        if ($line -match $expiryKeywordRegex) {
            $context = @()
            if ($i -gt 0) { $context += [string]$lines[$i - 1] }
            if ($i + 1 -lt $lines.Count) { $context += [string]$lines[$i + 1] }
            $countsByClass['expiry-keyword'] += 1
            $findings.Add([ordered]@{
                    class = 'expiry-keyword'; file = $relPath; line = $lineNum; text = $line.Trim(); context = $context
                })
        }

        # -- 3. Provisional markers (with blame age) --
        if ($line -match $provisionalRegex) {
            $ageDays = $null
            $blameDate = $null
            if ($gitAvailable) {
                $blameRaw = & git -C $root blame -L "$lineNum,$lineNum" -porcelain - $relPath 2>$null
                if ($blameRaw) {
                    $timeLine = @($blameRaw | Where-Object { $_ -match '^author-time (\d+)' })[0]
                    if ($timeLine -and $timeLine -match '^author-time (\d+)') {
                        $epoch = [long]$matches[1]
                        $blameDateObj = ([datetime]'1970-01-01Z').AddSeconds($epoch)
                        $blameDate = $blameDateObj.ToString('yyyy-MM-dd')
                        $ageDays = [int]((Get-Date).ToUniversalTime() - $blameDateObj).TotalDays
                    }
                }
            }
            $rotten = ($null -ne $ageDays) -and ($ageDays -ge $ProvisionalAgeDays)
            $countsByClass['provisional'] += 1
            $findings.Add([ordered]@{
                    class     = 'provisional'; file = $relPath; line = $lineNum; text = $line.Trim()
                    ageDays   = $ageDays
                    rotten    = $rotten
                    blameDate = $blameDate
                })
        }

        # -- 4. 32-Bit-Zeit-Verdacht --
        if ($line -match $int32TimeRegex) {
            $countsByClass['int32-time'] += 1
            $findings.Add([ordered]@{ class = 'int32-time'; file = $relPath; line = $lineNum; text = $line.Trim() })
        }
    }
}

$result = [ordered]@{
    findings      = $findings.ToArray()
    countsByClass = $countsByClass
    gitAvailable  = $gitAvailable
    scannedFiles  = $scannedFiles
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== TIMEBOMB-SCAN ==="
Write-Output "  Scanned files: $scannedFiles"
foreach ($k in $countsByClass.Keys) { Write-Output "  ${k}: $($countsByClass[$k])" }
Write-Output "  Git verfuegbar: $gitAvailable"
