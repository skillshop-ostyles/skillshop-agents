[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('ts', 'tsx', 'js', 'jsx', 'py', 'cs', 'go', 'rs', 'java', 'php', 'rb', 'kt'),
    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage', '__pycache__')
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

$accessPaths = New-Object System.Collections.Generic.List[object]
$counts = @{ total = 0; safe = 0; racy = 0; deadlockProne = 0; toctou = 0 }

$allFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
    Where-Object { -not (Test-ExcludedPath $_.FullName) }

$sharedStatePatterns = @(
    '(?i)(\blet\s+\w+|var\s+\w+|const\s+\w+)\s*[:=]\s*(new\s+)?(Map|Set|Array|Object|\[|\{)',
    '(?i)(global|globalThis|GLOBAL|process\.env|module\.exports|exports)\.\w+\s*[=:]',
    '(?i)(static|Shared|volatile)\s+\w+\s*(=|:)',
    '(?i)\b(mutex|lock|synchronized|Mutex|Lock|Semaphore|Monitor|atomic|Atomic|spinlock|RwLock)\b',
    '(?i)\b(async|await|Promise|Task\.Run|goroutine|go\s+|thread|Thread|spawn|par\.|parallel)\b',
    '(?i)\b(race|concurrent|parallel|shared|reentrant|thread.?safe)\b'
)

$stateVars = @{}

foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    $content = $lines -join "`n"

    # Find mutable state declarations at module/class level
    $declMatches = [regex]::Matches($content, '(?i)(?:^|\n)\s*(let|var|const|static|global|private\s+\w+)\s+(\w+)\s*[=:]')
    foreach ($dm in $declMatches) {
        $stateVar = $dm.Groups[2].Value
        if (-not $stateVar -or $stateVar -match '^(if|for|while|switch|function|return|class)') { continue }

        # Skip framework imports and common module-level aliases
        if ($stateVar -match '^(express|app|router|server|appInstance|koa|fastify)$') { continue }
        # Skip vars initialized from a require/import call (not shared state)
        $declLineNumber = $dm.Groups[0].Value
        if ($declLineNumber -match '=\s*(require\(|import\s)') { continue }

        if (-not $stateVars.ContainsKey($stateVar)) {
            $stateVars[$stateVar] = [ordered]@{ file = $relPath; reads = 0; writes = 0; hasSync = $false; crossesAsync = $false }
        }
    }

    # Find shared state access
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = [string]$lines[$i]
        $lineNum = $i + 1

        $isWrite = $line -match '[=:]\s*' -and -not ($line -match '(?i)(==|===|!=|!==|<=|>=|:|=~|match)')
        $crossesAsync = $line -match '(?i)(async|await|Promise|\.then\(|callback|setTimeout|setInterval|addEventListener)'
        $hasSync = $line -match '(?i)(mutex|lock|synchronized|atomic|Mutex|Lock|Semaphore|Monitor)'

        # Check each declared state variable
        foreach ($sv in $stateVars.Keys) {
            if ($line -match "\b$sv\b") {
                $stateVars[$sv].reads++
                if ($isWrite) { $stateVars[$sv].writes++ }
                if ($hasSync -or $line -match "\b$sv\b.*(mutex|lock|synchronized)") { $stateVars[$sv].hasSync = $true }
                if ($crossesAsync) { $stateVars[$sv].crossesAsync = $true }

                $counts.total++

                # Classify
                $classification = 'safe'
                if ($stateVars[$sv].writes -gt 1 -and $crossesAsync -and -not $stateVars[$sv].hasSync) {
                    $classification = 'racy'
                    $counts.racy++
                }
                elseif ($sv -match '(?i)(lock|mutex|semaphore|monitor)' -and $content -match '(?is)(?:lock\b|\.acquire\b).*(?:\n.*){1,5}(?:lock\b|\.acquire\b)') {
                    $classification = 'deadlock-prone'
                    $counts.deadlockProne++
                }
                elseif ($stateVars[$sv].reads -gt 0 -and $stateVars[$sv].writes -gt 0 -and -not $stateVars[$sv].hasSync) {
                    $classification = 'toctou'
                    $counts.toctou++
                }
                else {
                    $counts.safe++
                }

                $accessPaths.Add([ordered]@{
                        stateVar        = $sv
                        file            = $relPath
                        line            = $lineNum
                        accessType      = if ($isWrite) { 'write' } else { 'read' }
                        hasSync         = $hasSync -or $stateVars[$sv].hasSync
                        crossesAsyncBoundary = $crossesAsync
                        classification  = $classification
                    })
                break
            }
        }
    }
}

$result = [ordered]@{
    accessPaths = $accessPaths.ToArray()
    counts      = $counts
    stateVars   = $stateVars
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== SHARED-STATE-SCAN ==="
Write-Output "  Shared state access paths: $($counts.total)"
Write-Output "  Safe: $($counts.safe)"
Write-Output "  Racy: $($counts.racy)"
Write-Output "  Deadlock-prone: $($counts.deadlockProne)"
Write-Output "  TOCTOU: $($counts.toctou)"
