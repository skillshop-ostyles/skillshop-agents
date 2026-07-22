[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [Parameter(Mandatory = $true)]
    [string[]]$Files,

    [int]$MaxCommits = 500,
    [int]$MinCoChanges = 3
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir does not exist: $ProjectDir"
    exit 1
}

$isRepo = & git -C $ProjectDir rev-parse -is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0 -or $isRepo -ne 'true') {
    Write-Error "Not a git repo: $ProjectDir"
    exit 1
}

# ProjectDir can be a subfolder of the actual repo root (e.g. "src").
# git show -name-only ALWAYS returns paths relative to the repo root, while -Files
# (as in intent-archaeology) are specified relative to ProjectDir - determine
# the prefix to make both consistently comparable/printable.
$repoRootRaw = & git -C $ProjectDir rev-parse -show-toplevel 2>$null
$repoRoot = (($repoRootRaw -join '') -replace '\\', '/').TrimEnd('/')
$projectDirFull = ((Resolve-Path -LiteralPath $ProjectDir).Path -replace '\\', '/').TrimEnd('/')
$prefix = ''
if ($projectDirFull -ne $repoRoot -and $projectDirFull.StartsWith("$repoRoot/")) {
    $prefix = $projectDirFull.Substring($repoRoot.Length + 1) + '/'
}

function ConvertTo-ProjectRelative($nameFromGit) {
    if ($prefix -and $nameFromGit.StartsWith($prefix)) {
        return $nameFromGit.Substring($prefix.Length)
    }
    return $nameFromGit
}

$targets = @()
$truncatedAny = $false

foreach ($file in $Files) {
    $fileNorm = $file -replace '\\', '/'

    $hashLines = & git -C $ProjectDir log '-format=%H' - $file 2>$null
    $hashes = @()
    if ($hashLines) { $hashes = @(($hashLines -join "`n") -split "`n" | Where-Object { $_.Trim() -ne '' }) }
    $totalCommitCount = $hashes.Count
    $truncated = $totalCommitCount -gt $MaxCommits
    if ($truncated) { $truncatedAny = $true }
    $usedHashes = if ($truncated) { $hashes[0..($MaxCommits - 1)] } else { $hashes }

    $coCounts = @{}
    foreach ($h in $usedHashes) {
        $namesRaw = & git -C $ProjectDir show -name-only '-format=' $h 2>$null
        if (-not $namesRaw) { continue }
        $names = @(($namesRaw -join "`n") -split "`n" | Where-Object { $_.Trim() -ne '' })
        foreach ($n in $names) {
            $nRel = ConvertTo-ProjectRelative ($n.Trim())
            if ($nRel -eq $fileNorm) { continue }
            if (-not $coCounts.ContainsKey($nRel)) { $coCounts[$nRel] = 0 }
            $coCounts[$nRel] += 1
        }
    }

    $commitCountForRatio = $usedHashes.Count
    # foreach-as-expression instead of "+=" on an array of [ordered] hashtables -
    # the latter triggers a Dynamic-Binder bug in PowerShell 5.1 (see
    # ref-scan.ps1, discovered during testing there).
    $coChanged = @(
        foreach ($kv in ($coCounts.GetEnumerator() | Sort-Object -Property Value -Descending)) {
            if ($kv.Value -lt $MinCoChanges) { continue }
            $ratio = if ($commitCountForRatio -gt 0) { [Math]::Round($kv.Value / $commitCountForRatio, 2) } else { 0 }
            [ordered]@{ file = $kv.Key; together = $kv.Value; ratio = $ratio }
        }
    )

    $targets += [ordered]@{
        file        = $fileNorm
        commitCount = $totalCommitCount
        coChanged   = $coChanged
    }
}

$result = [ordered]@{
    targets   = $targets
    truncated = $truncatedAny
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== CO-CHANGE ==="
foreach ($t in $targets) {
    Write-Output "  $($t.file): $($t.commitCount) Commits, $($t.coChanged.Count) gekoppelte Dateien (ab $MinCoChanges)"
    foreach ($cc in ($t.coChanged | Select-Object -First 3)) {
        Write-Output "    - $($cc.file): $($cc.together)x zusammen (Ratio $($cc.ratio))"
    }
}
