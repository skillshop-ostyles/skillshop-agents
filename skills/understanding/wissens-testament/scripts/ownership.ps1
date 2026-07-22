[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Author,
    [switch]$ListAuthors,

    [string[]]$Extensions = @('ts', 'tsx', 'js', 'jsx', 'py', 'cs', 'go', 'rs', 'java', 'php', 'rb', 'vue', 'sql', 'ps1'),
    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage'),
    [int]$TopN = 30
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir existiert nicht: $ProjectDir"
    exit 1
}

$isRepo = & git -C $ProjectDir rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0 -or $isRepo -ne 'true') {
    Write-Error "Kein Git-Repo: $ProjectDir"
    exit 1
}

if ($ListAuthors) {
    $shortlogRaw = & git -C $ProjectDir shortlog -sne --all 2>$null
    $authors = @(
        foreach ($line in $shortlogRaw) {
            $m = [regex]::Match([string]$line, '^\s*(\d+)\s+(.+)$')
            if ($m.Success) {
                [ordered]@{ commits = [int]$m.Groups[1].Value; author = $m.Groups[2].Value.Trim() }
            }
        }
    )
    Write-Output (ConvertTo-Json ([ordered]@{ authors = $authors }) -Depth 4)
    Write-Output "`n=== OWNERSHIP: Autorenliste ==="
    foreach ($a in $authors) { Write-Output "  $($a.commits)`t$($a.author)" }
    exit 0
}

if (-not $Author -or $Author.Count -eq 0) {
    Write-Error "-Author ist Pflicht (ausser bei -ListAuthors). Nutze -ListAuthors, um Kandidaten zu sehen."
    exit 1
}

function Test-AuthorMatch($name, $mail, $authorList) {
    foreach ($a in $authorList) {
        $aTrim = $a.Trim()
        $emailMatch = [regex]::Match($aTrim, '<([^>]+)>')
        if ($emailMatch.Success -and $mail -and ($emailMatch.Groups[1].Value -eq $mail)) { return $true }
        $namePart = ($aTrim -replace '<[^>]*>', '').Trim()
        if ($namePart -and $name -and ($namePart -eq $name)) { return $true }
        if ($aTrim -eq $mail -or $aTrim -eq $name) { return $true }
    }
    return $false
}

# --- Commits des Autors mit betroffenen Dateien (fuer Hotspots + Anker-Commits) ---
$format = "$([char]0x01)%H$([char]0x1f)%ad$([char]0x1f)%s$([char]0x02)"
$authorArgs = @()
foreach ($a in $Author) { $authorArgs += "--author=$a" }
$rawLines = & git -C $ProjectDir log $authorArgs '--date=short' "--pretty=format:$format" --name-only 2>$null
$raw = if ($rawLines) { ($rawLines -join "`n") } else { '' }

$commits = @()
if ($raw) {
    $chunks = @($raw -split [char]0x01 | Where-Object { $_.Trim() -ne '' })
    foreach ($chunk in $chunks) {
        $sepIdx = $chunk.IndexOf([char]0x02)
        if ($sepIdx -lt 0) { continue }
        $header = $chunk.Substring(0, $sepIdx).Trim()
        $filesPart = $chunk.Substring($sepIdx + 1)
        $fields = $header -split [char]0x1f
        $files = @($filesPart -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' })
        $commits += [ordered]@{
            hash         = $fields[0].Trim()
            date         = $fields[1].Trim()
            subject      = $fields[2].Trim()
            filesTouched = $files.Count
            files        = $files
        }
    }
}

if ($commits.Count -eq 0) {
    Write-Error "Keine Commits fuer Autor '$($Author -join ', ')' gefunden. -ListAuthors zeigt gueltige Kandidaten."
    exit 1
}

# --- Hotspots: Datei -> Anzahl Commits des Autors ---
$hotspotCounts = @{}
foreach ($c in $commits) {
    foreach ($f in $c.files) {
        if (-not $hotspotCounts.ContainsKey($f)) { $hotspotCounts[$f] = 0 }
        $hotspotCounts[$f] += 1
    }
}
$hotspots = @(
    $hotspotCounts.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First $TopN |
        ForEach-Object { [ordered]@{ file = $_.Key; commits = $_.Value } }
)

# --- Blame-Anteile fuer die TopN Hotspot-Dateien ---
$soleOwnership = @(
    foreach ($h in $hotspots) {
        $blameRaw = & git -C $ProjectDir blame --line-porcelain -- $h.file 2>$null
        if (-not $blameRaw) { continue }
        $totalLines = 0
        $authorLines = 0
        $identitiesSeen = @{}
        $isTargetSeen = $false
        $curName = $null
        $curMail = $null
        foreach ($line in $blameRaw) {
            if ($line.StartsWith('author ')) { $curName = $line.Substring(7) }
            elseif ($line.StartsWith('author-mail ')) { $curMail = $line.Substring(12).Trim().Trim('<', '>') }
            elseif ($line.StartsWith("`t")) {
                $totalLines++
                $isTarget = Test-AuthorMatch $curName $curMail $Author
                $identity = if ($curMail) { $curMail } else { $curName }
                if ($isTarget) { $identitiesSeen['__target__'] = $true } else { $identitiesSeen[$identity] = $true }
                if ($isTarget) { $authorLines++ }
            }
        }
        if ($totalLines -eq 0) { continue }
        $share = [Math]::Round($authorLines / $totalLines, 2)
        if ($share -ge 0.6) {
            $otherAuthors = @($identitiesSeen.Keys | Where-Object { $_ -ne '__target__' }).Count
            [ordered]@{ file = $h.file; blameShare = $share; otherAuthors = $otherAuthors }
        }
    }
)

$criticalExclusive = @($soleOwnership | Where-Object { $_.otherAuthors -le 1 } | ForEach-Object { $_.file })

$anchorCommits = @(
    $commits | Sort-Object -Property filesTouched -Descending | Select-Object -First 15 |
        ForEach-Object { [ordered]@{ hash = $_.hash; date = $_.date; subject = $_.subject; filesTouched = $_.filesTouched } }
)

$result = [ordered]@{
    author            = ($Author -join ', ')
    soleOwnership     = $soleOwnership
    hotspots          = $hotspots
    criticalExclusive = $criticalExclusive
    anchorCommits     = $anchorCommits
    commitsAnalyzed   = $commits.Count
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== OWNERSHIP: $($Author -join ', ') ==="
Write-Output "  Commits analysiert: $($commits.Count)"
Write-Output "  Hotspot-Dateien (TopN=$TopN): $($hotspots.Count)"
Write-Output "  Alleinbesitz-Kandidaten (>= 60%): $($soleOwnership.Count)"
Write-Output "  Kritisches Alleinwissen (<= 1 weiterer Autor): $($criticalExclusive.Count)"
Write-Output "  Anker-Commits: $($anchorCommits.Count)"
