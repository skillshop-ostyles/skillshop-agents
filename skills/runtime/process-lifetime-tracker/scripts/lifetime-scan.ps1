[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('ts', 'tsx', 'js', 'jsx', 'py', 'cs', 'go', 'rs', 'java', 'php', 'rb', 'kt', 'yaml', 'yml', 'dockerfile', 'Dockerfile'),
    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage', '__pycache__', '.next', '.nuxt')
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

$processes = New-Object System.Collections.Generic.List[object]
$counts = @{ total = 0; graceful = 0; rough = 0; abrupt = 0; dangerous = 0 }

$allFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
    Where-Object { -not (Test-ExcludedPath $_.FullName) }

foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    $content = $lines -join "`n"

    # --- Detect HTTP server declarations ---
    $httpPatterns = @(
        '(?i)createServer',
        '(?i)\.listen\s*\(',
        '(?i)app\.listen',
        '(?i)flask\s+run',
        '(?i)FastAPI',
        '(?i)uvicorn\.run'
    )
    foreach ($pat in $httpPatterns) {
        $matches = [regex]::Matches($content, $pat)
        foreach ($m in $matches) {
            $hasShutdown = $content -match '(?i)server\.(close|destroy)\s*\('
            $shutdownMechanism = if ($hasShutdown) { 'server.close/destroy' } else { 'none detected' }
            $hasGrace = $content -match '(?i)(grace\s*period|gracePeriod|graceful)'
            $drainsConn = $content -match '(?i)(drain|connection.*close|conn.*end)'
            $cleansUp = $content -match '(?i)(cleanup|finally|disconnect|destroy)'
            $hasSignal = $content -match '(?i)(SIGTERM|SIGINT|process\.on|shutdown)'

            $classification = 'abrupt'
            if ($hasShutdown -and $hasGrace -and $drainsConn) { $classification = 'graceful' }
            elseif ($hasSignal) { $classification = 'rough' }

            $counts.total++
            $counts.$classification++

            $processes.Add([ordered]@{
                    name = $relPath
                    type = 'http-server'
                    entryFile = $relPath
                    hasShutdownHandler = $hasShutdown -or $hasSignal
                    shutdownMechanism = $shutdownMechanism
                    hasGracePeriod = $hasGrace
                    drainsConnections = $drainsConn
                    cleansUpResources = $cleansUp
                    classification = $classification
                })
        }
    }

    # --- Detect worker declarations ---
    $workerPatterns = @(
        '(?i)\b(bull|sidekiq|celery|Hangfire|agenda|bee-queue)\b',
        '(?i)Worker\s*\(',
        '(?i)Queue\s+',
        '(?i)\.process\s*\(',
        '(?i)\.addListener\s*'
    )
    foreach ($pat in $workerPatterns) {
        $matches = [regex]::Matches($content, $pat)
        foreach ($m in $matches) {
            $hasShutdown = $content -match '(?i)(worker\.close|queue\.close|drain|destroy|shutdown)'
            $shutdownMechanism = if ($hasShutdown) { 'close/drain/destroy' } else { 'none detected' }
            $hasGrace = $content -match '(?i)(grace\s*period|gracePeriod|graceful)'
            $drainsConn = $content -match '(?i)drain'
            $cleansUp = $content -match '(?i)(cleanup|finally|disconnect|destroy)'
            $hasSignal = $content -match '(?i)(SIGTERM|SIGINT|process\.on|shutdown)'

            $classification = 'abrupt'
            if ($hasShutdown -and $hasGrace -and $drainsConn) { $classification = 'graceful' }
            elseif ($hasSignal) { $classification = 'rough' }

            $counts.total++
            $counts.$classification++

            $processes.Add([ordered]@{
                    name = $relPath
                    type = 'worker'
                    entryFile = $relPath
                    hasShutdownHandler = $hasShutdown -or $hasSignal
                    shutdownMechanism = $shutdownMechanism
                    hasGracePeriod = $hasGrace
                    drainsConnections = $drainsConn
                    cleansUpResources = $cleansUp
                    classification = $classification
                })
        }
    }

    # --- Detect daemon scripts (setInterval, while(true), cron) ---
    $daemonPatterns = @(
        '(?i)while\s*\(\s*true\s*\)',
        '(?i)setInterval',
        '(?i)\bcron\b',
        '(?i)schedule\(|\.schedule\(',
        '(?i)every\(\s*[''""]\d+\s*(seconds?|minutes?|hours?)\s*[''""]'
    )
    foreach ($pat in $daemonPatterns) {
        $matches = [regex]::Matches($content, $pat)
        foreach ($m in $matches) {
            $hasShutdown = $content -match '(?i)(clearInterval|clearTimeout|stop|destroy|cancel)'
            $shutdownMechanism = if ($hasShutdown) { 'clearInterval/stop/cancel' } else { 'none detected' }
            $hasGrace = $content -match '(?i)(grace\s*period|gracePeriod|graceful)'
            $drainsConn = $false
            $cleansUp = $content -match '(?i)(cleanup|finally|disconnect|destroy|rollback)'
            $hasSignal = $content -match '(?i)(SIGTERM|SIGINT|process\.on|shutdown)'

            $classification = 'abrupt'
            if ($hasShutdown -and $hasGrace -and $cleansUp) { $classification = 'graceful' }
            elseif ($hasSignal -or $hasShutdown) { $classification = 'rough' }

            # Check for DB migrations / transactions without rollback -> dangerous
            if ($content -match '(?i)(migrate|transaction|commit|insert|update|delete)') {
                $hasRollback = $content -match '(?i)(rollback|undo|revert)'
                if (-not $hasRollback) { $classification = 'dangerous' }
            }

            $counts.total++
            $counts.$classification++

            $processes.Add([ordered]@{
                    name = $relPath
                    type = 'daemon'
                    entryFile = $relPath
                    hasShutdownHandler = $hasShutdown -or $hasSignal
                    shutdownMechanism = $shutdownMechanism
                    hasGracePeriod = $hasGrace
                    drainsConnections = $drainsConn
                    cleansUpResources = $cleansUp
                    classification = $classification
                })
        }
    }

    # --- Detect k8s/Docker entry points ---
    $entryPatterns = @(
        '(?i)ENTRYPOINT\s+',
        '(?i)CMD\s+',
        '(?i)command:\s+',
        '(?i)args:\s+'
    )
    # Skip Dockerfile check for non-docker files — patterns above are generic enough
    $isDockerFile = $f.Name -match '(?i)dockerfile'
    if ($isDockerFile) {
        foreach ($pat in $entryPatterns) {
            $matches = [regex]::Matches($content, $pat)
            foreach ($m in $matches) {
                $hasSignal = $content -match '(?i)(SIGTERM|SIGINT|stop|exec\s+)'
                $shutdownMechanism = if ($hasSignal) { 'exec/signal forwarded' } else { 'default (PID 1)' }
                $hasGrace = $content -match '(?i)(grace\s*period|gracePeriod|stop-grace-period|timeout)'
                $cleansUp = $false

                $classification = 'abrupt'
                if ($hasSignal -and $hasGrace) { $classification = 'graceful' }
                elseif ($hasSignal) { $classification = 'rough' }

                $counts.total++
                $counts.$classification++

                $processes.Add([ordered]@{
                        name = $relPath
                        type = 'entrypoint'
                        entryFile = $relPath
                        hasShutdownHandler = $hasSignal
                        shutdownMechanism = $shutdownMechanism
                        hasGracePeriod = $hasGrace
                        drainsConnections = $false
                        cleansUpResources = $cleansUp
                        classification = $classification
                    })
            }
        }
    }
}

$result = [ordered]@{
    processes = $processes.ToArray()
    counts    = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== LIFETIME-SCAN ==="
Write-Output "  Total processes: $($counts.total) (graceful=$($counts.graceful) rough=$($counts.rough) abrupt=$($counts.abrupt) dangerous=$($counts.dangerous))"
