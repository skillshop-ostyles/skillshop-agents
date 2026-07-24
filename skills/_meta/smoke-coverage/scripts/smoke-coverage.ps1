[CmdletBinding()]
param([string]$ProjectDir)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = if ($ProjectDir) { (Resolve-Path $ProjectDir).Path } else { (Get-Location).Path }
$clusters = Get-ChildItem $root/skills -Directory | Where-Object { $_.Name -notmatch '^_' } | ForEach-Object { $_.Name }
$report = New-Object System.Collections.Generic.List[object]
$totals = @{ covered = 0; partial = 0; uncovered = 0; total = 0 }

foreach ($cluster in $clusters) {
    Get-ChildItem "$root/skills/$cluster" -Directory | ForEach-Object {
        $totals.total++
        $skill = $_.Name
        $fixtureDir = "$root/skills/$cluster/$skill/tests/fixtures/smoke/src"
        $scriptDir = "$root/skills/$cluster/$skill/scripts"
        $hasFixture = Test-Path $fixtureDir -and (Get-ChildItem $fixtureDir -File).Count -gt 0
        $hasScripts = Test-Path $scriptDir -and (Get-ChildItem $scriptDir -Filter *.ps1).Count -gt 0
        $status = if ($hasFixture -and $hasScripts) { 'covered' } elseif ($hasScripts) { 'partial' } else { 'uncovered' }
        $totals[$status]++
        $report.Add([ordered]@{ cluster = $cluster; skill = $skill; hasScripts = $hasScripts; hasFixture = $hasFixture; status = $status })
    }
}
Write-Output (ConvertTo-Json ([ordered]@{ skills = $report.ToArray(); totals = $totals }) -Depth 6)
Write-Output "`n=== SMOKE-COVERAGE ===`n  Covered: $($totals.covered) | Partial: $($totals.partial) | Uncovered: $($totals.uncovered) | Total: $($totals.total)"
