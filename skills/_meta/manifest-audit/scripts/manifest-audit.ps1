[CmdletBinding()]
param([string]$ProjectDir)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = if ($ProjectDir) { (Resolve-Path $ProjectDir).Path } else { (Get-Location).Path }
$tracking = Join-Path $root 'ops/tracking.md'
$readme = Join-Path $root 'README.md'

$diskSkills = Get-ChildItem $root/skills -Recurse -Filter SKILL.md | ForEach-Object {
    $_.DirectoryName.Substring($root.Length).TrimStart('\').Replace('\','/')
} | Sort-Object

$tracked = if (Test-Path $tracking) {
    (Get-Content $tracking -Raw) -split "`n" | Where-Object { $_ -match '-> ' } | ForEach-Object { ($_ -split '-> ')[1].Trim() -replace '\s+\|.*','' }
} else { @() }

$readmeList = if (Test-Path $readme) {
    $rm = Get-Content $readme -Raw
    $rm -split "`n" | Where-Object { $_ -match '^\| \/' } | ForEach-Object { ($_ -split '\|')[1].Trim().TrimStart('/') }
} else { @() }

$onDisk = $diskSkills | ForEach-Object { $_ -replace '^[^/]+/', '' -replace '/SKILL\.md$', '' }
$missingFromTracking = $onDisk | Where-Object { $_ -notin $tracked }
$missingFromDisk = $tracked | Where-Object { $_ -notin $onDisk }
$inTrackingNotReadme = $tracked | Where-Object { $_ -notin $readmeList }

Write-Output (ConvertTo-Json ([ordered]@{
    totalOnDisk = $onDisk.Count; totalTracked = $tracked.Count; totalInReadme = $readmeList.Count
    missingFromTracking = @($missingFromTracking); missingFromDisk = @($missingFromDisk)
    inTrackingNotReadme = @($inTrackingNotReadme)
}) -Depth 6)
Write-Output "`n=== MANIFEST-AUDIT ===`n  Disk: $($onDisk.Count) | Tracking: $($tracked.Count) | README: $($readmeList.Count)"
if ($missingFromTracking) { Write-Output "  Not in tracking: $($missingFromTracking -join ', ')" }
if ($missingFromDisk) { Write-Output "  Not on disk: $($missingFromDisk -join ', ')" }
