[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('ts', 'tsx', 'js', 'jsx', 'py', 'cs', 'go', 'rs', 'java', 'php', 'rb', 'yaml', 'yml', 'json', 'toml', 'ini'),
    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage')
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir does not exist: $ProjectDir"
    exit 1
}

$root = (Resolve-Path -LiteralPath $ProjectDir).Path
$excludeSet = @($Exclude | ForEach-Object { $_.ToLower() })
$extSet = @($Extensions | ForEach-Object { $_.TrimStart('.').ToLower() })

function Test-ExcludedPath($fullPath) {
    $rel = $fullPath.Substring($root.Length).TrimStart('\', '/')
    foreach ($part in ($rel -split '[\\/]')) {
        if ($excludeSet -contains $part.ToLower()) { return $true }
    }
    return $false
}

$limits = New-Object System.Collections.Generic.List[object]
$counts = @{ total = 0; adequate = 0; approaching = 0; critical = 0 }

$limitPatterns = @(
    '(?i)(connection.?pool|pool.?size|max.?pool|db.?pool)\s*[=:]\s*(\d+)',
    '(?i)(max.?connections|max_connections|connection.?limit)\s*[=:]\s*(\d+)',
    '(?i)(timeout|time.?out)\s*[=:]\s*(\d+)',
    '(?i)(max.?retries|retry.?count|maxRetries)\s*[=:]\s*(\d+)',
    '(?i)(rate.?limit|ratelimit|throttle)\s*[=:]\s*(\d+)',
    '(?i)(max.?body.?size|maxBodySize|body.?limit|upload.?limit)\s*[=:]\s*(\d+)',
    '(?i)(page.?size|pagination.?limit|per.?page|limit)\s*[=:]\s*(\d+)',
    '(?i)(batch.?size|batchSize|chunk.?size)\s*[=:]\s*(\d+)',
    '(?i)(worker.?count|workerCount|concurrency)\s*[=:]\s*(\d+)',
    '(?i)(queue.?depth|queue.?size|max.?queue)\s*[=:]\s*(\d+)',
    '(?i)(buffer.?size|bufferSize|cache.?ttl|max.?age)\s*[=:]\s*(\d+)',
    '(?i)(disk.?quota|max.?storage|storage.?limit)\s*[=:]\s*(\d+)'
)

$allFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
    Where-Object { -not (Test-ExcludedPath $_.FullName) }

foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    $content = $lines -join "`n"

    foreach ($pat in $limitPatterns) {
        $matches = [regex]::Matches($content, $pat)
        foreach ($m in $matches) {
            $nameVal = $m.Groups[1].Value
            $val = [int]$m.Groups[2].Value
            $unit = 'count'
            if ($nameVal -match '(?i)(timeout|ttl|age)') { $unit = 'ms' }

            # Determine config mechanism
            $configMechanism = 'hardcoded'
            if ($content -match '(?i)(env|process\.env|config|setting|app\.config)') { $configMechanism = 'config-file' }

            $counts.total++

            # Rough heuristic: values < 10 for pool/connections are critical
            $assessment = 'adequate'
            if ($val -le 5 -and $nameVal -match '(?i)(pool|connection|worker|concurrency)') { $assessment = 'critical' }
            elseif ($val -le 20 -and $nameVal -match '(?i)(pool|connection|worker|concurrency)') { $assessment = 'approaching' }
            elseif ($val -le 1000 -and $unit -eq 'ms' -and $nameVal -match '(?i)timeout') { $assessment = 'approaching' }
            elseif ($val -le 100 -and $unit -eq 'ms' -and $nameVal -match '(?i)timeout') { $assessment = 'critical' }

            # Check for monitoring nearby
            $hasMonitoring = $content -match '(?i)(metric|monitor|alert|warn|threshold|gauge|counter|histogram)'

            switch ($assessment) {
                'adequate' { $counts.adequate++ }
                'approaching' { $counts.approaching++ }
                'critical' { $counts.critical++ }
            }

            $limits.Add([ordered]@{
                    file           = $relPath
                    name           = $nameVal
                    value          = $val
                    unit           = $unit
                    configMechanism = $configMechanism
                    assessment     = $assessment
                    hasMonitoring  = $hasMonitoring
                })
        }
    }
}

$result = [ordered]@{
    limits     = $limits.ToArray()
    counts     = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== LIMIT-HARVEST ==="
Write-Output "  Total limits found: $($counts.total)"
Write-Output "  Adequate: $($counts.adequate)"
Write-Output "  Approaching: $($counts.approaching)"
Write-Output "  Critical: $($counts.critical)"
