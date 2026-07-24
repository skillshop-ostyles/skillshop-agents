[CmdletBinding()]
param([string]$ProjectDir)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = if ($ProjectDir) { (Resolve-Path $ProjectDir).Path } else { (Get-Location).Path }
$triggers = New-Object System.Collections.Generic.List[object]
$readme = Get-Content (Join-Path $root 'README.md') -Raw
$readmeTriggers = @([regex]::Matches($readme, '(?i)\| `/[\w-]+`').Value -replace '\| `|`','')

Get-ChildItem $root/skills -Recurse -Filter SKILL.md | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $rel = $_.FullName.Substring($root.Length).TrimStart('\')
    $trigger = if ($content -match 'trigger:\s*(/\S+)') { $matches[1] } else { '' }
    $violations = @()
    if ($trigger -and $trigger -notmatch '^/[a-z][a-z0-9-]*$') { $violations += 'bad-format' }
    if ($trigger -and $readmeTriggers -contains $trigger -and ($rel -notmatch '/_meta/')) { $violations += 'duplicate-in-readme' }
    $triggers.Add([ordered]@{ skill = $rel; trigger = $trigger; violations = $violations })
}

$dups = $triggers.trigger | Group-Object | Where-Object { $_.Count -gt 1 -and $_.Name }
$readmeMiss = $triggers | Where-Object { $_.trigger -and $_trigger -notin $readmeTriggers -and $_.skill -notmatch '/_meta/' }

Write-Output (ConvertTo-Json ([ordered]@{
    triggers = $triggers.ToArray(); duplicates = @($dups | ForEach-Object { $_.Name })
    readmeMissing = @($readmeMiss | ForEach-Object { $_.trigger })
}) -Depth 6)
Write-Output "`n=== TRIGGER-AUDIT ===`n  Duplicates: $($dups.Count) | Missing from README: $($readmeMiss.Count)"
