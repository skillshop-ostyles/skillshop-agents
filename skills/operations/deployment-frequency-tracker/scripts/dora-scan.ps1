[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [int]$WindowDays = 90
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir does not exist: $ProjectDir"
    exit 1
}

$root = (Resolve-Path -LiteralPath $ProjectDir).Path

# Check git availability
$gitAvailable = $false
$gitRoot = $null
$repoCheck = & git -C $root rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -eq 0 -and $repoCheck -eq 'true') {
    $gitAvailable = $true
    $gitRoot = & git -C $root rev-parse --show-toplevel 2>$null
}

$metrics = [ordered]@{
    deployFrequency       = $null
    avgLeadTimeDays       = $null
    changeFailureRate     = $null
    avgRestoreTimeHours   = $null
    totalDeploys          = 0
    totalCommits          = 0
    hotfixCount           = 0
    rollbackCount         = 0
    trends                = [ordered]@{}
    blockingPatterns      = @()
}

if (-not $gitAvailable) {
    $metrics.deployFrequency = 'N/A (no git repo)'
    Write-Output (ConvertTo-Json $metrics -Depth 6)
    Write-Output "`n=== DORA-SCAN ==="
    Write-Output "  Not a git repository"
    exit 0
}

$now = Get-Date
$windowStart = $now.AddDays(-$WindowDays)

# Get all commits in window
$logOutput = & git -C $gitRoot log --oneline --after=$($windowStart.ToString('yyyy-MM-dd')) --before=$($now.ToString('yyyy-MM-dd')) --format="%H %ct %s" 2>$null
$commits = $logOutput | Where-Object { $_ -match '^(\S+)\s+(\d+)\s+(.+)$' }
$metrics.totalCommits = $commits.Count

if ($metrics.totalCommits -eq 0) {
    Write-Output (ConvertTo-Json $metrics -Depth 6)
    Write-Output "`n=== DORA-SCAN ==="
    Write-Output "  No commits in window"
    exit 0
}

# Identify deploys: merge commits or tagged commits
$deploys = @()
$hotfixes = @()
$rollbacks = @()

foreach ($c in $commits) {
    if ($c -match '(\S+)\s+(\d+)\s+(.+)') {
        $hash = $matches[1]
        $ts = [long]$matches[2]
        $msg = $matches[3]
        $date = ([datetime]'1970-01-01Z').AddSeconds($ts)

        # Check for deploy indicators
        $isDeploy = $msg -match '(?i)(release|deploy|rollout|publish|v\d+\.\d+|tag:\s*v|Merge pull request|Merge branch)'
        $isHotfix = $msg -match '(?i)(hotfix|hot.?fix|emergency|critical.?fix|patch)'
        $isRollback = $msg -match '(?i)(rollback|revert|undo|backout)'

        if ($isDeploy) {
            $deploys += [ordered]@{ hash = $hash; date = $date.ToString('yyyy-MM-dd'); message = $msg.Trim() }
        }
        if ($isHotfix) { $hotfixes += $hash }
        if ($isRollback) { $rollbacks += $hash }
    }
}

$metrics.totalDeploys = $deploys.Count
$metrics.hotfixCount = $hotfixes.Count
$metrics.rollbackCount = $rollbacks.Count

# Deployment frequency (per day)
$daysInWindow = [Math]::Max(1, ($now - $windowStart).TotalDays)
$metrics.deployFrequency = [Math]::Round($metrics.totalDeploys / $daysInWindow, 2)

# Change failure rate
if ($metrics.totalDeploys -gt 0) {
    $failureEvents = $metrics.hotfixCount + $metrics.rollbackCount
    $metrics.changeFailureRate = [Math]::Round(($failureEvents / $metrics.totalDeploys) * 100, 1)
}
else {
    $metrics.changeFailureRate = 0
}

# Lead time (rough: time from first non-deploy commit to deploy)
if ($deploys.Count -gt 0) {
    $leadTimes = @()
    foreach ($d in $deploys) {
        $deployDate = [datetime]::ParseExact($d.date, 'yyyy-MM-dd', $null)
        $priorCommits = $commits | Where-Object {
            $_ -match '\S+\s+(\d+)\s+.+'
            $commitDate = ([datetime]'1970-01-01Z').AddSeconds([long]$matches[1])
            $commitDate -le $deployDate -and $commitDate -ge $deployDate.AddDays(-30)
        } | Select-Object -First 1
        if ($priorCommits -and ($priorCommits -match '\S+\s+(\d+)')) {
            $priorEpoch = [long]$matches[1]
            $priorCommitDate = ([datetime]'1970-01-01Z').AddSeconds($priorEpoch)
            $leadTimes += ($deployDate - $priorCommitDate).TotalDays
        }
    }
    if ($leadTimes.Count -gt 0) {
        $metrics.avgLeadTimeDays = [Math]::Round(($leadTimes | Measure-Object -Average).Average, 1)
    }
}

# Time to restore (rough: time from failure deploy to fix deploy)
if ($hotfixes.Count -gt 0 -or $rollbacks.Count -gt 0) {
    $restoreTimes = @()
    $failureCommits = $hotfixes + $rollbacks
    foreach ($fc in $failureCommits) {
        $fcDate = & git -C $gitRoot log -1 --format="%ct" $fc 2>$null
        if ($fcDate) {
            $fcDateTime = ([datetime]'1970-01-01Z').AddSeconds([long]$fcDate)
            # Find next deploy after failure
            foreach ($d in $deploys) {
                $dd = [datetime]::ParseExact($d.date, 'yyyy-MM-dd', $null)
                if ($dd -gt $fcDateTime) {
                    $restoreTimes += ($dd - $fcDateTime).TotalHours
                    break
                }
            }
        }
    }
    if ($restoreTimes.Count -gt 0) {
        $metrics.avgRestoreTimeHours = [Math]::Round(($restoreTimes | Measure-Object -Average).Average, 1)
    }
}

# Trends: compare first half vs second half of window
$halfWindow = $windowStart.AddDays($daysInWindow / 2)
$firstHalf = $commits | Where-Object { $_ -match '\S+\s+(\d+)' -and ([datetime]'1970-01-01Z').AddSeconds([long]$matches[1]) -lt $halfWindow } | Measure-Object | Select-Object -ExpandProperty Count
$secondHalf = $commits | Where-Object { $_ -match '\S+\s+(\d+)' -and ([datetime]'1970-01-01Z').AddSeconds([long]$matches[1]) -ge $halfWindow } | Measure-Object | Select-Object -ExpandProperty Count

if ($secondHalf -gt $firstHalf) { $metrics.trends.commitVelocity = 'increasing' }
elseif ($secondHalf -lt $firstHalf) { $metrics.trends.commitVelocity = 'decreasing' }
else { $metrics.trends.commitVelocity = 'stable' }

# Blocking patterns
if ($metrics.changeFailureRate -gt 20) {
    $metrics.blockingPatterns += 'High change failure rate suggests risky deployments or insufficient testing'
}
if ($metrics.avgLeadTimeDays -gt 7) {
    $metrics.blockingPatterns += 'Long lead time suggests large batch deployments or slow review process'
}
if ($metrics.deployFrequency -lt 0.14) {
    $metrics.blockingPatterns += 'Low deployment frequency (<1/week) suggests manual deployment process'
}

$result = [ordered]@{
    metrics = $metrics
    deploys = $deploys
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== DORA-SCAN ==="
Write-Output "  Commits in window: $($metrics.totalCommits)"
Write-Output "  Deployments: $($metrics.totalDeploys) (freq: $($metrics.deployFrequency)/day)"
Write-Output "  Change failure rate: $($metrics.changeFailureRate)%"
Write-Output "  Avg lead time: $($metrics.avgLeadTimeDays) days"
Write-Output "  Avg restore time: $($metrics.avgRestoreTimeHours) hours"
