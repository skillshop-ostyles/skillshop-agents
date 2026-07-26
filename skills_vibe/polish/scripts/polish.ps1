[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ProjectDir,

    [ValidateSet('all', 'consolelog', 'anytype', 'nofallback', 'magic', 'deadimport', 'aismell')]
    [string[]]$Checks = @('all')
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$resolvedDir = Resolve-Path -LiteralPath $ProjectDir -ErrorAction Stop
$scriptDir = Split-Path -Parent $PSCommandPath

$allChecks = @('consolelog', 'anytype', 'nofallback', 'magic', 'deadimport', 'aismell')
$checkOrder = if ($Checks -eq 'all' -or $Checks -contains 'all') { $allChecks } else { $Checks }

$results = @()
$totalFindings = 0
$failedCount = 0

foreach ($check in $checkOrder) {
    $scriptPath = Join-Path $scriptDir "check-$check.ps1"
    if (-not (Test-Path $scriptPath)) {
        Write-Output "  [$($checkOrder.IndexOf($check)+1)/$($checkOrder.Count)] $check ... [SKIP - no script]"
        continue
    }

    Write-Output "=== POLISH: $check ==="

    try {
        $output = & $scriptPath -ProjectDir $resolvedDir 2>&1
        $jsonText = ($output | Out-String).Trim()
        $result = $jsonText | ConvertFrom-Json

        $fCount = $result.findings.Count
        $totalFindings += $fCount

        $status = if ($result.status -eq 'pass') { 'PASS' } elseif ($result.status -eq 'fail') { "FAIL ($fCount)" } else { $result.status }
        Write-Output "  [$($checkOrder.IndexOf($check)+1)/$($checkOrder.Count)] $check ... [$status]"

        if ($result.status -eq 'fail') { $failedCount++ }

        $results += $result
    } catch {
        Write-Output "  [$($checkOrder.IndexOf($check)+1)/$($checkOrder.Count)] $check ... [ERROR]"
        $results += @{ check = $check; status = 'error'; findings = @(); summary = @{} }
    }
}

$passedCount = @($results | Where-Object { $_.status -eq 'pass' }).Count
$skippedCount = @($results | Where-Object { $_.status -eq 'skip' -or $_.status -eq 'error' }).Count

Write-Output "`n=== POLISH SUMMARY ==="
Write-Output "  Checks: $($checkOrder.Count) | Pass: $passedCount | Issues: $failedCount | Skipped: $skippedCount"
Write-Output "  Total findings: $totalFindings"

Write-Output "`nFULL_RESULT_BEGIN"
$aggregate = @{
    summary = @{
        checks_run = $checkOrder.Count
        checks_passed = $passedCount
        checks_with_issues = $failedCount
        total_findings = $totalFindings
    }
    results = $results
}
Write-Output ($aggregate | ConvertTo-Json -Depth 4)
Write-Output "FULL_RESULT_END"
