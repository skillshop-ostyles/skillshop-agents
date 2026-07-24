[CmdletBinding()]
param([string]$ProjectDir)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = if ($ProjectDir) { (Resolve-Path $ProjectDir).Path } else { (Get-Location).Path }
$orig = Get-Location; Set-Location $root
$skills = New-Object System.Collections.Generic.List[object]
$now = Get-Date

Get-ChildItem $root/skills -Recurse -Filter SKILL.md | ForEach-Object {
    $dir = $_.Directory.FullName; $rel = $dir.Substring($root.Length).TrimStart('\')
    $cluster = ($rel -split '[\\/]')[0]; $skillName = ($rel -split '[\\/]')[1]
    $lastMod = (Get-Item $dir).LastWriteTime
    $ageDays = [math]::Round(($now - $lastMod).TotalDays)
    $content = Get-Content $_.FullName -Raw
    $hasScripts = (Get-ChildItem "$dir/scripts" -Filter *.ps1 -ErrorAction SilentlyContinue).Count -gt 0
    $hasFixture = (Get-ChildItem "$dir/tests" -Recurse -ErrorAction SilentlyContinue).Count -gt 0
    $gitLog = git log --oneline -1 -- $rel 2>$null
    $lastCommit = if ($gitLog) { ($gitLog -split ' ')[0] } else { 'never' }

    $issues = @()
    if ($ageDays -gt 90) { $issues += 'stale (>90 days since last mod)' }
    if (-not $hasFixture) { $issues += 'no smoke fixture' }
    $status = if ($issues.Count -eq 0) { 'healthy' } elseif ($issues.Count -eq 1) { 'aging' } else { 'stale' }

    $skills.Add([ordered]@{
        skill = $skillName; cluster = $cluster; ageDays = $ageDays; lastCommit = $lastCommit
        hasScripts = $hasScripts; hasFixture = $hasFixture; issues = $issues; status = $status
    })
}
Set-Location $orig

$counts = @{ healthy = ($skills | Where-Object { $_.status -eq 'healthy' }).Count; aging = ($skills | Where-Object { $_.status -eq 'aging' }).Count; stale = ($skills | Where-Object { $_.status -eq 'stale' }).Count }
Write-Output (ConvertTo-Json ([ordered]@{ skills = $skills.ToArray(); counts = $counts }) -Depth 6)
Write-Output "`n=== SKILL-LIFECYCLE ===`n  Healthy: $($counts.healthy) | Aging: $($counts.aging) | Stale: $($counts.stale)"
