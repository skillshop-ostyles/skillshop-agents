[CmdletBinding()]
param([string]$ProjectDir, [switch]$RunAll)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

$root = if ($ProjectDir) { (Resolve-Path $ProjectDir).Path } else { (Get-Location).Path }
$results = New-Object System.Collections.Generic.List[object]

Get-ChildItem $root/skills -Recurse -Filter '*.ps1' | Where-Object { $_.DirectoryName -match 'scripts' } | ForEach-Object {
    $fixtureDir = Join-Path $_.Directory.Parent.FullName 'tests/fixtures/smoke/src'
    if (-not (Test-Path $fixtureDir)) { return }
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $output = try { & $_.FullName -ProjectDir $fixtureDir 2>&1 | Out-String } catch { "ERROR: $_" }
    $sw.Stop()
    $rel = $_.FullName.Substring($root.Length).TrimStart('\')
    $hasError = $output -match 'ERROR' -or $LASTEXITCODE -ne 0
    $jsonLines = ($output -split "`n" | Where-Object { $_ -match '^\{' -or $_ -match '^\[' }).Count
    $results.Add([ordered]@{
        script = $rel; timeMs = $sw.ElapsedMilliseconds; outputLines = ($output -split "`n").Count
        jsonObjects = $jsonLines; hasError = $hasError; status = if ($hasError) { 'FAIL' } else { 'PASS' }
    })
}
$passCount = ($results | Where-Object { $_.status -eq 'PASS' }).Count
$failCount = ($results | Where-Object { $_.status -eq 'FAIL' }).Count
Write-Output (ConvertTo-Json ([ordered]@{ benchmarks = $results.ToArray(); pass = $passCount; fail = $failCount }) -Depth 6)
Write-Output "`n=== BENCHMARK ===`n  Pass: $passCount | Fail: $failCount | Total: $($results.Count)"
