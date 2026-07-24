[CmdletBinding()]
param([string]$ProjectDir)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = if ($ProjectDir) { (Resolve-Path $ProjectDir).Path } else { (Get-Location).Path }
$bibel = Join-Path $root 'ops/BIBEL.md'
if (-not (Test-Path $bibel)) { Write-Error "No ops/BIBEL.md found"; exit 1 }

$bibelContent = Get-Content $bibel -Raw
$checks = @()
$total = 0; $pass = 0; $violation = 0; $smokeFail = 0

Get-ChildItem $root/skills -Recurse -Filter SKILL.md | ForEach-Object {
    $total++
    $dir = $_.DirectoryName
    $rel = $dir.Substring($root.Length).TrimStart('\')
    $lines = Get-Content $_.FullName -Raw
    $issues = @()
    if ($lines -notmatch '\[CmdletBinding\(\)\]') { $issues += 'missing [CmdletBinding()]' }
    if ($lines -notmatch 'Stop') { $issues += 'missing ErrorActionPreference Stop' }
    if (Test-Path "$dir/scripts") {
        Get-ChildItem "$dir/scripts" -Filter *.ps1 | ForEach-Object {
            $sc = Get-Content $_.FullName -Raw
            if ($sc -notmatch '=== ') { $issues += "$($_.Name) missing === TITLE ===" }
            if ($sc -notmatch 'ConvertTo-Json') { $issues += "$($_.Name) missing ConvertTo-Json output" }
            if ($sc -notmatch 'OutputEncoding.*UTF8') { $issues += "$($_.Name) missing UTF-8 encoding" }
        }
    }
    if ($issues.Count -eq 0) { $pass++ } else { $violation++ }
    $checks += [ordered]@{ skill = $rel; issues = $issues; status = if ($issues.Count -eq 0) { 'pass' } else { 'violation' } }
}

Write-Output (ConvertTo-Json ([ordered]@{ checks = $checks; counts = @{ total = $total; pass = $pass; violation = $violation } }) -Depth 6)
Write-Output "`n=== BIBEL-GATE ===`n  Total: $total | Pass: $pass | Violations: $violation"
