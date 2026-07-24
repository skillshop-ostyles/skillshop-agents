[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('ts', 'tsx', 'js', 'jsx', 'py', 'cs', 'go', 'rs', 'java', 'php', 'rb', 'yaml', 'yml'),
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

$endpoints = New-Object System.Collections.Generic.List[object]
$counts = @{ total = 0; adequate = 0; weak = 0; missing = 0 }

# Find health endpoint declarations in code
$allFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
    Where-Object { -not (Test-ExcludedPath $_.FullName) }

foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    $content = $lines -join "`n"

    # Detect health route patterns
    $healthPatterns = @(
        '/(health|healthz|ready|readiness|liveness|status)\b',
        '\.(health|readiness|liveness)\b',
        '(health_check|healthcheck|is_healthy)\s*='
    )

    foreach ($pat in $healthPatterns) {
        $matches = [regex]::Matches($content, $pat)
        foreach ($m in $matches) {
            $counts.total++

            $pathPart = $m.Groups[1].Value
            if (-not $pathPart) { $pathPart = 'health' }
            $path = '/' + $pathPart.Replace('_', '-')

            $type = 'health'
            if ($path -match '(ready|readiness|liveness)') { $type = 'readiness' }
            if ($path -match 'live') { $type = 'liveness' }

            $hasDbCheck = $content -match '(?i)(db|database|sql|postgres|mysql|mongo).*?(ping|connect|status|health|alive)'
            $hasCacheCheck = $content -match '(?i)(redis|cache|memcache).*?(ping|connect|status|health|alive)'
            $hasApiCheck = $content -match '(?i)(api|http|fetch|request).*?(health|status|ping)'
            $checkedDeps = @()
            if ($hasDbCheck) { $checkedDeps += 'database' }
            if ($hasCacheCheck) { $checkedDeps += 'cache' }
            if ($hasApiCheck) { $checkedDeps += 'external-api' }

            $assessment = 'weak'
            if ($checkedDeps.Count -ge 2) { $assessment = 'adequate' }

            $returnsConstant = $content -match '(?i)(ok|true|200)'
            if ($returnsConstant -and ($content -match '(?i)(db|cache|api|check|ping|query)')) {
                $returnsConstant = $false
            }

            if ($returnsConstant) { $assessment = 'weak' }
            if ($path -match '(liveness|live)') { $assessment = 'adequate' }

            switch ($assessment) {
                'adequate' { $counts.adequate++ }
                'weak' { $counts.weak++ }
                'missing' { $counts.missing++ }
            }

            $endpoints.Add([ordered]@{
                    file       = $relPath
                    path       = $path
                    type       = $type
                    checkedDeps = $checkedDeps
                    assessment = $assessment
                    returnsConstant = $returnsConstant
                })
        }
    }
}

# Also check k8s probe configs in YAML
$yamlFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { ($_.Extension -eq '.yaml') -or ($_.Extension -eq '.yml') } |
    Where-Object { -not (Test-ExcludedPath $_.FullName) }

foreach ($f in $yamlFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    $probeTypes = @('livenessProbe', 'readinessProbe', 'startupProbe')
    foreach ($pt in $probeTypes) {
        if ($content -match "$pt\s*:") {
            $probeMatch = [regex]::Match($content, 'httpGet:\s*\n\s+path:\s*(\S+)')
            if ($probeMatch.Success) { $probePath = $probeMatch.Groups[1].Value } else { $probePath = '/' }
            $counts.total++
            $counts.adequate++
            $endpoints.Add([ordered]@{
                    file       = $relPath
                    path       = $probePath
                    type       = $pt.ToLower()
                    checkedDeps = @('process')
                    assessment = 'adequate'
                    returnsConstant = $false
                })
        }
    }
}

$result = [ordered]@{
    endpoints  = $endpoints.ToArray()
    counts     = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== HEALTHCHECK-SCAN ==="
Write-Output "  Total health endpoints: $($counts.total)"
Write-Output "  Adequate: $($counts.adequate)"
Write-Output "  Weak: $($counts.weak)"
