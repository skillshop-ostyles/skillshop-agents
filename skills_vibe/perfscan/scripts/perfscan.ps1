[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ProjectDir,

    [ValidateSet('all', 'high', 'keyprops', 'useeffect', 'layoutshift', 'images', 'client', 'bundle', 'render')]
    [string[]]$Checks = @('all')
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$resolvedDir = Resolve-Path -LiteralPath $ProjectDir -ErrorAction Stop
$scriptDir = Split-Path -Parent $PSCommandPath

$highChecks = @('keyprops', 'useeffect', 'layoutshift')
$mediumChecks = @('images', 'client', 'bundle')
$lowChecks = @('render')
$allChecks = $highChecks + $mediumChecks + $lowChecks

if ($Checks -eq 'all' -or $Checks -contains 'all') {
    $checkOrder = $allChecks
} elseif ($Checks -eq 'high' -or $Checks -contains 'high') {
    $checkOrder = $highChecks
} else {
    $checkOrder = @($Checks | Where-Object { $_ -ne 'high' })
}

$results = @()
$totalHigh = 0; $totalMedium = 0; $totalLow = 0

foreach ($check in $checkOrder) {
    $scriptPath = Join-Path $scriptDir "check-$check.ps1"
    if (-not (Test-Path $scriptPath)) {
        Write-Output "  [$($checkOrder.IndexOf($check)+1)/$($checkOrder.Count)] $check ... [SKIP]"
        continue
    }

    Write-Output "=== PERFSCAN: $check ==="
    try {
        $output = & $scriptPath -ProjectDir $resolvedDir 2>&1
        $jsonText = ($output | Out-String).Trim()
        $result = $jsonText | ConvertFrom-Json

        $fCount = $result.findings.Count
        if ($check -in $highChecks) { $totalHigh += $fCount }
        elseif ($check -in $mediumChecks) { $totalMedium += $fCount }
        else { $totalLow += $fCount }

        $status = if ($result.status -eq 'pass') { 'PASS' } elseif ($result.status -eq 'fail') { "FAIL ($fCount)" } else { $result.status }
        Write-Output "  [$($checkOrder.IndexOf($check)+1)/$($checkOrder.Count)] $check ... [$status]"
        $results += $result
    } catch {
        Write-Output "  [$($checkOrder.IndexOf($check)+1)/$($checkOrder.Count)] $check ... [ERROR]"
        $results += @{ check = $check; status = 'error'; findings = @(); summary = @{} }
    }
}

$passedCount = @($results | Where-Object { $_.status -eq 'pass' }).Count

Write-Output "`n=== PERFSCAN SUMMARY ==="
if ($totalHigh -gt 0) { Write-Output "  HIGH: $totalHigh findings" }
if ($totalMedium -gt 0) { Write-Output "  MEDIUM: $totalMedium findings" }
if ($totalLow -gt 0) { Write-Output "  LOW: $totalLow findings" }
Write-Output "  Total: $($totalHigh + $totalMedium + $totalLow) findings across $($checkOrder.Count) checks"

Write-Output "`nFULL_RESULT_BEGIN"
$aggregate = @{
    summary = @{
        checks_run = $checkOrder.Count
        checks_passed = $passedCount
        total_findings = $totalHigh + $totalMedium + $totalLow
        by_impact = @{ high = $totalHigh; medium = $totalMedium; low = $totalLow }
    }
    results = $results
}
Write-Output ($aggregate | ConvertTo-Json -Depth 4)
Write-Output "FULL_RESULT_END"
