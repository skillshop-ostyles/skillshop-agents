[CmdletBinding()]
param([string]$ProjectDir, [string]$Bibeldiff)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = if ($ProjectDir) { (Resolve-Path $ProjectDir).Path } else { (Get-Location).Path }
if (-not $Bibeldiff -or -not (Test-Path $Bibeldiff)) { Write-Error "-Bibeldiff path required"; exit 1 }
$newBibel = Get-Content (Resolve-Path $Bibeldiff) -Raw
$oldBibelPath = Join-Path $root 'ops/BIBEL.md'
$oldBibel = if (Test-Path $oldBibelPath) { Get-Content $oldBibelPath -Raw } else { '' }

$oldRules = $oldBibel -split '`{3,}' | Where-Object { $_ -match '\[CmdletBinding|ErrorAction|OutputEncoding|ConvertTo-Json|=== TITLE ===' }
$newRules = $newBibel -split '`{3,}' | Where-Object { $_ -match '\[CmdletBinding|ErrorAction|OutputEncoding|ConvertTo-Json|=== TITLE ===' }
$added = $newRules | Where-Object { $_ -notin $oldRules }
$removed = $oldRules | Where-Object { $_ -notin $newRules }

$affected = New-Object System.Collections.Generic.List[object]
Get-ChildItem $root/skills -Recurse -Filter '*.ps1' | ForEach-Object {
    $content = Get-Content $_.FullName -Raw; $missing = @()
    if ($added -match 'CmdletBinding' -and $content -notmatch '\[CmdletBinding\(\)\]') { $missing += '[CmdletBinding()]' }
    if ($added -match 'ErrorAction' -and $content -notmatch 'ErrorActionPreference.*Stop') { $missing += 'ErrorActionPreference Stop' }
    if ($added -match 'OutputEncoding' -and $content -notmatch 'OutputEncoding') { $missing += 'UTF-8 OutputEncoding' }
    if ($added -match 'ConvertTo-Json' -and $content -notmatch 'ConvertTo-Json') { $missing += 'ConvertTo-Json' }
    if ($added -match '===' -and $content -notmatch '=== \w+ ===') { $missing += '=== TITLE === summary' }
    if ($missing.Count -gt 0) { $affected.Add([ordered]@{ file = $_.FullName.Substring($root.Length); missing = $missing }) }
}

Write-Output (ConvertTo-Json ([ordered]@{ rulesAdded = @($added); rulesRemoved = @($removed); affected = $affected.ToArray(); totalAffected = $affected.Count }) -Depth 6)
Write-Output "`n=== IMPACT ===`n  Rules added: $($added.Count) | Removed: $($removed.Count) | Affected scripts: $($affected.Count)"
