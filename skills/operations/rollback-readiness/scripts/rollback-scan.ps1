[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

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

function Test-ExcludedPath($fullPath) {
    $rel = $fullPath.Substring($root.Length).TrimStart('\', '/')
    foreach ($part in ($rel -split '[\\/]')) {
        if ($excludeSet -contains $part.ToLower()) { return $true }
    }
    return $false
}

$changes = New-Object System.Collections.Generic.List[object]
$counts = @{ total = 0; hasRollback = 0; noRollback = 0; safe = 0; risky = 0 }

# Check git availability
$gitAvailable = $false
if (Test-Path -LiteralPath (Join-Path $root '.git')) {
    $gitAvailable = $true
}

# If git available, analyze recent diff
if ($gitAvailable) {
    $diffOutput = & git -C $root diff HEAD~1 --stat 2>$null
    if ($?) {
        # Get changed files list
        $changedFiles = & git -C $root diff HEAD~1 --name-only 2>$null
        foreach ($f in $changedFiles) {
            $relPath = $f.Replace('\', '/')

            $kind = 'code-change'
            $hasRollback = $false
            $rollbackMechanism = $null

            # Detect DB migration files
            if ($relPath -match '(?i)(migration|migrate|schema)\b.*\.sql$') {
                $kind = 'db-migration'
                # Check if down migration exists
                $content = Get-Content -LiteralPath (Join-Path $root $f) -Raw -ErrorAction SilentlyContinue
                if ($content -match '(?i)(down|rollback|revert|undo|drop\s+table|alter\s+table|remove)') {
                    $hasRollback = $true
                    $rollbackMechanism = 'contains down/revert commands'
                }
            }

            # Detect API endpoint changes
            if ($relPath -match '\.(ts|js|py|cs|java)$') {
                $content = Get-Content -LiteralPath (Join-Path $root $f) -Raw -ErrorAction SilentlyContinue
                if ($content -match '(?i)(@api|@route|router\.|app\.(get|post|put|delete|patch))') {
                    $kind = 'api-change'
                    if ($content -match '(?i)(version|v[12]|deprecat|backward|compat)') {
                        $hasRollback = $true
                        $rollbackMechanism = 'versioned API or compat layer'
                    }
                }
            }

            $counts.total++
            if ($hasRollback) { $counts.hasRollback++ } else { $counts.noRollback++ }

            $changes.Add([ordered]@{
                    kind             = $kind
                    element          = $relPath
                    hasRollback      = $hasRollback
                    rollbackMechanism = $rollbackMechanism
                    coordinationRequired = $false
                })
        }
    }
}
else {
    $counts.total++
    $counts.noRollback++
    $changes.Add([ordered]@{
            kind             = 'info'
            element          = 'no-git-history'
            hasRollback      = $false
            rollbackMechanism = $null
            coordinationRequired = $false
        })
}

# Also scan for feature flags without removal criteria
$allFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { -not (Test-ExcludedPath $_.FullName) } |
    Where-Object { $_.Name -match '\.(ts|js|py|cs|java|json|yaml|yml)$' }

foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    if ($content -match '(?i)(feature.?flag|feature.?toggle|feature_gate)\s*:\s*(true|on|enabled)') {
        $hasRemovalCriteria = $content -match '(?i)(removal|sunset|expir|deprecat|remove\s+(by|after|in)|migration\s+plan)'
        $counts.total++
        if ($hasRemovalCriteria) { $counts.hasRollback++ } else { $counts.noRollback++ }
        $changes.Add([ordered]@{
                kind             = 'feature-flag'
                element          = $relPath
                hasRollback      = $hasRemovalCriteria
                rollbackMechanism = if ($hasRemovalCriteria) { 'has removal criteria' } else { $null }
                coordinationRequired = $true
            })
    }
}

$result = [ordered]@{
    changes = $changes.ToArray()
    counts  = $counts
    gitAvailable = $gitAvailable
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== ROLLBACK-SCAN ==="
Write-Output "  Changes found: $($counts.total)"
Write-Output "  With rollback path: $($counts.hasRollback)"
Write-Output "  Without rollback path: $($counts.noRollback)"
