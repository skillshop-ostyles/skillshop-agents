[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('ts', 'tsx', 'js', 'jsx', 'py', 'cs', 'go', 'rs', 'java', 'php', 'rb', 'kt', 'swift'),
    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage', '__pycache__', 'bin', 'obj')
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

$initSteps = New-Object System.Collections.Generic.List[object]
$counts = @{ total = 0; critical = 0; deferrable = 0; suspicious = 0; byPhase = [ordered]@{} }

# Entry point files to focus on
$entryPatterns = @('index.ts', 'index.js', 'main.ts', 'main.js', 'app.ts', 'app.js', 'server.ts', 'server.js',
    'main.py', 'app.py', 'wsgi.py', 'manage.py', 'Program.cs', 'Startup.cs', 'main.go',
    'Main.kt', 'AppDelegate.swift')

$allFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
    Where-Object { -not (Test-ExcludedPath $_.FullName) }

# Phase 1: Find entry points and module-level code
foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    $content = $lines -join "`n"
    $isEntry = $entryPatterns -contains $f.Name.ToLower()

    # Detect import/require/using at module level (not inside functions)
    $inFunction = 0
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = [string]$lines[$i]
        $lineNum = $i + 1

        # Track function/class depth
        if ($line -match '(?i)\b(function|def |class |=>\s*\{|async\s+\()') { $inFunction++ }
        elseif ($line -match '^\s*\}') { $inFunction = [Math]::Max(0, $inFunction - 1) }

        if ($inFunction -gt 0 -and -not $isEntry) { continue }

        $phase = $null
        $description = $null
        $isLazyLoadable = $false

        # Module-level imports
        if ($line -match '(?i)^\s*(import|require|from |using |include|#include|use\s+)\s+\S') {
            $phase = 'import'
            $description = $line.Trim()
            $isLazyLoadable = $true
            # Detect if the import is used widely (not lazy-loadable heuristic)
            $importTarget = $line -replace '^.*?(?:from|require|import|using|use)\s+[''"]?([^''"'';]+)[''"]?.*$', '$1'
            if ($importTarget -match '(?i)(express|fastapi|flask|react|vue|angular|koa|spring|django|server|app)') {
                $isLazyLoadable = $false
            }
        }
        # Init/startup/connection patterns
        elseif ($line -match '(?i)(connect|createPool|createConnection|initialize|configure|setup|bootstrap)\s*\(' -and $inFunction -eq 0) {
            $phase = if ($line -match '(?i)(mongo|pg|mysql|redis|db|database)') { 'pool' } else { 'init' }
            $description = $line.Trim()
        }
        # Scheduler/cron registration
        elseif ($line -match '(?i)(schedule|cron|timer|setInterval|setTimeout|agenda|bull|sidekiq|celery|hangfire)\s*\(') {
            $phase = 'scheduler'
            $description = $line.Trim()
        }
        # Migration checks
        elseif ($line -match '(?i)(migrate|migration|schema.*sync|db.*sync|ensure.*schema)') {
            $phase = 'migration'
            $description = $line.Trim()
        }
        # Cache warming
        elseif ($line -match '(?i)(cache.*warm|preload|prefetch|prime|warm.*cache)') {
            $phase = 'cache'
            $description = $line.Trim()
        }
        # Health endpoint registration
        elseif ($line -match '(?i)(health|healthcheck|readiness|liveness).*(endpoint|route|check)') {
            $phase = 'health'
            $description = $line.Trim()
        }

        if ($phase) {
            if (-not $counts.byPhase.Contains($phase)) { $counts.byPhase[$phase] = 0 }
            $counts.byPhase[$phase]++
            $counts.total++

            $classification = if ($isLazyLoadable) { 'deferrable' } else { 'critical' }
            if ($line -match '(?i)(console\.log|process\.env|side.?effect|global|singleton)') { $classification = 'suspicious' }

            switch ($classification) {
                'critical' { $counts.critical++ }
                'deferrable' { $counts.deferrable++ }
                'suspicious' { $counts.suspicious++ }
            }

            $initSteps.Add([ordered]@{
                    phase       = $phase
                    file        = $relPath
                    line        = $lineNum
                    description = $description
                    classification = $classification
                })
        }
    }
}

$result = [ordered]@{
    initSteps = $initSteps.ToArray()
    counts    = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== STARTUP-TRACE ==="
Write-Output "  Init steps: $($counts.total) (critical=$($counts.critical) deferrable=$($counts.deferrable) suspicious=$($counts.suspicious))"
foreach ($k in $counts.byPhase.Keys) { Write-Output "  $k`: $($counts.byPhase[$k])" }
