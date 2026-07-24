[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('ts', 'tsx', 'js', 'jsx', 'py', 'cs', 'go', 'rs', 'java', 'php', 'rb', 'yaml', 'yml', 'json'),
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

$caches = New-Object System.Collections.Generic.List[object]
$counts = @{ total = 0; effective = 0; tooShortTtl = 0; tooLongTtl = 0; missingInvalidation = 0; costExceeds = 0; scopeMismatch = 0; missedOpportunity = 0 }

$allFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
    Where-Object { -not (Test-ExcludedPath $_.FullName) }

foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    $content = $lines -join "`n"

    # Detect caching patterns
    # 1. Redis/Memcached
    $cacheMatches = [regex]::Matches($content, '(?i)(redis|memcache|ioredis|redisClient|client)\.(get|set|setex|setnx)\s*\(')
    foreach ($m in $cacheMatches) {
        $line = $content.Substring(0, [Math]::Min($m.Index + 100, $content.Length))
        $keyPattern = if ($line -match "['""]([^'""]+)['""]") { $matches[1] } else { 'dynamic-key' }
        $ttl = if ($line -match '(?i)(EX|PX|expire)\s*,\s*(\d+)') { [int]$matches[2] } else { $null }
        $hasInvalidation = $content -match '(?i)(del|delete|expire|flush|unlink)\s*\('

        $counts.total++
        $assessment = 'effective'
        if ($null -ne $ttl -and $ttl -lt 10) { $assessment = 'too-short-ttl'; $counts.tooShortTtl++ }
        elseif ($null -ne $ttl -and $ttl -gt 86400) { $assessment = 'too-long-ttl'; $counts.tooLongTtl++ }
        elseif (-not $hasInvalidation) { $assessment = 'missing-invalidation'; $counts.missingInvalidation++ }
        else { $counts.effective++ }

        $caches.Add([ordered]@{
                file       = $relPath
                mechanism  = 'redis'
                keyPattern = $keyPattern
                ttl        = $ttl
                hasInvalidation = $hasInvalidation
                assessment = $assessment
            })
    }

    # 2. In-memory Map/object caches
    if ($content -match '(?i)(Map|WeakMap|new Map|LRU|lru-cache|node-cache|memory-cache|memoize|memo)') {
        $hasTtl = $content -match '(?i)(ttl|maxAge|expire|stale)'
        $hasInvalidation = $content -match '(?i)(delete|del|clear|invalidate|remove|evict)'

        $counts.total++
        $assessment = 'effective'
        if (-not $hasInvalidation) { $assessment = 'missing-invalidation'; $counts.missingInvalidation++ }
        elseif ($hasTtl -and -not $hasInvalidation) { $assessment = 'too-long-ttl'; $counts.tooLongTtl++ }
        else { $counts.effective++ }

        $caches.Add([ordered]@{
                file       = $relPath
                mechanism  = 'in-memory'
                keyPattern = 'variable-key'
                ttl        = $null
                hasInvalidation = $hasInvalidation
                assessment = $assessment
            })
    }

    # 3. HTTP caching headers
    if ($content -match '(?i)(Cache-Control|ETag|Expires|Last-Modified|max-age|s-maxage)') {
        $maxAge = if ($content -match '(?i)max-age\s*[=:]\s*(\d+)') { [int]$matches[1] } else { $null }

        $counts.total++
        $assessment = 'effective'
        if ($null -ne $maxAge -and $maxAge -gt 86400) { $assessment = 'too-long-ttl'; $counts.tooLongTtl++ }
        else { $counts.effective++ }

        $caches.Add([ordered]@{
                file       = $relPath
                mechanism  = 'http-cache-header'
                keyPattern = 'url-based'
                ttl        = $maxAge
                hasInvalidation = $false
                assessment = $assessment
            })
    }

    # 4. Detect frequent DB queries without cache (missed opportunity)
    if ($content -match '(?i)(SELECT|find|findMany|query|get)') {
        $isInLoop = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '(?i)\b(for|while|forEach|map)\s*\(') {
                for ($j = $i + 1; $j -lt [Math]::Min($lines.Count, $i + 5); $j++) {
                    if ($lines[$j] -match '(?i)(SELECT|find|query|get)') {
                        $isInLoop = $true
                        break
                    }
                }
            }
        }
        if ($isInLoop) {
            $counts.missedOpportunity++
            $caches.Add([ordered]@{
                    file       = $relPath
                    mechanism  = 'missed-opportunity'
                    keyPattern = 'N/A'
                    ttl        = $null
                    hasInvalidation = $false
                    assessment = 'missed-opportunity'
                })
        }
    }
}

$result = [ordered]@{
    caches = $caches.ToArray()
    counts = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== CACHE-HARVEST ==="
Write-Output "  Caches found: $($counts.total)"
Write-Output "  Effective: $($counts.effective)"
Write-Output "  Too-short TTL: $($counts.tooShortTtl)"
Write-Output "  Too-long TTL: $($counts.tooLongTtl)"
Write-Output "  Missing invalidation: $($counts.missingInvalidation)"
Write-Output "  Missed opportunities: $($counts.missedOpportunity)"
