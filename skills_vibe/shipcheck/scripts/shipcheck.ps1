[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ProjectDir,

    [ValidateSet('all', 'env', 'build', 'secrets')]
    [string[]]$Checks = @('all')
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$resolvedDir = Resolve-Path -LiteralPath $ProjectDir -ErrorAction Stop
$scriptDir = Split-Path -Parent $PSCommandPath

$checkOrder = @()
if ($Checks -eq 'all') { $checkOrder = @('env', 'build', 'secrets') }
else { $checkOrder = @($Checks) }

$allResults = @()
$totalFails = 0
$totalPass = 0

foreach ($check in $checkOrder) {
    $scriptPath = Join-Path $scriptDir "check-$check.ps1"
    if (-not (Test-Path $scriptPath)) {
        Write-Error "Check script not found: $scriptPath"
        continue
    }

    $progressLine = "  [$($checkOrder.IndexOf($check) + 1)/$($checkOrder.Count)] $check ... "
    Write-Output "=== SHIPCHECK: $check ==="

    try {
        $output = & $scriptPath -ProjectDir $resolvedDir 2>&1
        $jsonText = ($output | Out-String).Trim()
        $result = $jsonText | ConvertFrom-Json

        $line = "Check $($checkOrder.IndexOf($check) + 1)/$($checkOrder.Count): $check"
        if ($result.status -eq 'pass') {
            $line += " [PASS]"
        } elseif ($result.status -eq 'warn') {
            $line += " [WARN]"
        } elseif ($result.status -eq 'fail') {
            $line += " [FAIL]"
        } else {
            $line += " [SKIP]"
        }
        Write-Output $line

        if ($result.status -ne 'pass') {
            foreach ($f in $result.findings) {
                if ($f.status -eq 'fail' -or $f.type -eq 'error' -or $f.risk -eq 'critical') {
                    $totalFails++
                }
            }
        } else {
            $totalPass++
        }

        $allResults += $result
    } catch {
        Write-Output "Check $check error: $($_.Exception.Message)"
        $allResults += @{ check = $check; status = 'error'; findings = @(); summary = @{} }
    }
}

$totalChecks = $checkOrder.Count
$totalFindings = 0
foreach ($r in $allResults) { $totalFindings += $r.findings.Count }

$aggregate = @{
    summary = @{
        checks_run = $totalChecks
        checks_passed = ($allResults | Where-Object { $_.status -eq 'pass' }).Count
        checks_failed = ($allResults | Where-Object { $_.status -eq 'fail' }).Count
        checks_warned = ($allResults | Where-Object { $_.status -eq 'warn' }).Count
        total_findings = $totalFindings
        critical_findings = $totalFails
    }
    results = $allResults
}

Write-Output "`n=== SHIPCHECK SUMMARY ==="
Write-Output "  Checks: $totalChecks | Pass: $($aggregate.summary.checks_passed) | Warnings: $($aggregate.summary.checks_warned) | Failed: $($aggregate.summary.checks_failed)"
Write-Output "  Findings: $totalFindings ($($aggregate.summary.critical_findings) critical)"

Write-Output "`nFULL_RESULT_BEGIN"
Write-Output ($aggregate | ConvertTo-Json -Depth 4)
Write-Output "FULL_RESULT_END"
