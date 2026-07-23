[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.cs,*.go,*.java,*.rb,*.php",
    [string]$Exclude = ""
)

$ErrorActionPreference = 'Stop'
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

# Rate-limit decorator patterns.
# Output: which route gets rate-limited and with what config.
$decoratorPatterns = @(
    # Express-rate-limit: @limiter() decorator
    @{ regex='@limiter\s*\('; lib='express-rate-limit' },
    @{ regex='limiter\s*\(\s*\)\s*\.[\w]+\s*\(.*\)\s*\.\s*(?:get|post|put|delete|patch|all)\s*\('; lib='express-rate-limit' },
    # Express at route-level: app.<verb>(path, rateLimit(...))
    @{ regex='app\.(?:get|post|put|delete|patch|all)\s*\(\s*["\x27][^"\x27,]+["\x27]\s*,\s*(?:rateLimit|limiter)\s*\('; lib='express-rate-limit-direct' },
    # Flask: @limiter.limit()
    @{ regex='@limiter\.limit\s*\('; lib='flask-limiter' },
    @{ regex='@app\.route\s*\([^)]*\)\s*$'; lib='flask-route-def' },
    @{ regex='@app\.route\s*\(\s*["\x27][^"\x27]+["\x27]'; lib='flask-route-def' },
    # DRF/Django: throttle_classes
    @{ regex='throttle_classes\s*=\s*\[([^\]]+)\]'; lib='drf-throttle' },
    @{ regex='@throttle_classes\b'; lib='drf-decorator' },
    # Spring
    @{ regex='@RateLimiter\b'; lib='spring-rate' }
)

# Mutating endpoints (to detect "is this expensive endpoint rate-limited").
$mutatingRouteRegex = 'app\.(?:post|put|patch|delete)\s*\(\s*["\x27][^"\x27,]+["\x27]'

$limitedFileLines = @{}      # "file|line" -> hashtable details
$mutatingFileLines = @{}
$count = 0

foreach ($ext in ($Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    $items = Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue
    foreach ($i in $items) {
        $fn = $i.FullName
        $accept = $true
        if ($fn -match '[\\/]node_modules[\\/]|[\\/]\.git[\\/]|[\\/]venv[\\/]|[\\/]__pycache__[\\/]|[\\/]dist[\\/]|[\\/]build[\\/]|[\\/]bin[\\/]|[\\/]obj[\\/]') { $accept = $false }
        if ($accept -and ($fn -match '\.test\.|\.spec\.|_test\.py|Test\.cs')) { $accept = $false }
        if ($accept -and ($fn -match '[\\/]fixtures[\\/]')) { $accept = $true }
        if ($accept -and ($fn -match '[\\/]tests[\\/]fixtures[\\/]')) { $accept = $true }
        if ($accept -and ($fn -match '[\\/]tests[\\/]') -and ($fn -notmatch '[\\/]fixtures[\\/]')) { $accept = $false }
        if (-not $accept) { continue }
        $content = Get-Content -LiteralPath $fn -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $rel = $fn.Substring($ProjectDir.Length).TrimStart('\')
        $count += 1
        $lines = $content -split "`n"
        for ($li = 0; $li -lt $lines.Count; $li++) {
            $ln = $lines[$li].Trim()

            # Skip import / require / non-route declarations.
            if ($ln -match '^\s*(import|require|from|export\s+\{|//\s*|#)' ) { continue }

            $matchedDecorator = $false
            foreach ($p in $decoratorPatterns) {
                if ($ln -match $p.regex) {
                    $key = "$rel|$($li+1)"
                    if (-not $limitedFileLines.ContainsKey($key)) {
                        $limitedFileLines[$key] = @{
                            file = $rel; line = $li + 1
                            lib = $p.lib
                            decoratorLine = $ln
                        }
                    }
                    $matchedDecorator = $true
                    break
                }
            }

            # Collect mutating endpoints.
            if ($ln -match $mutatingRouteRegex) {
                $key = "$rel|$($li+1)"
                if (-not $mutatingFileLines.ContainsKey($key)) {
                    $mutatingFileLines[$key] = @{
                        file = $rel; line = $li + 1
                        mutatingLine = $ln
                    }
                }
            }
        }
    }
}

# Compute missing: a mutating endpoint has no limit if its (file|line) key
# is NOT in $limitedFileLines.
$allLimitedKeys = @($limitedFileLines.Keys)
$allMutatingKeys = @($mutatingFileLines.Keys)
$missingKeys = @()
foreach ($mk in $allMutatingKeys) {
    if ($mk -notin $allLimitedKeys) { $missingKeys += $mk }
}

# Rebuild display entries as hashtables (for clean JSON).
$limitedList = @()
$mutatingList = @()
$missingList = @()
foreach ($k in @($limitedFileLines.Keys)) {
    $limitedList += $limitedFileLines[$k]
}
foreach ($k in @($mutatingFileLines.Keys)) {
    $mutatingList += $mutatingFileLines[$k]
}
foreach ($mk in $missingKeys) {
    $missingList += $mutatingFileLines[$mk]
}

Write-Output "=== Rate-Limit-Shape Scan Complete ==="
Write-Output "  Files scanned: $count"
Write-Output "  Rate-limit decorators: $($allLimitedKeys.Count)"
Write-Output "  Mutating endpoints: $($allMutatingKeys.Count)"
Write-Output "  Mutating endpoints without rate-limit (file-local missing): $($missingKeys.Count)"

$result = @{
    limitedRoutes = $limitedList
    mutatingRoutes = $mutatingList
    missingLimits = $missingList
    counts = @{
        scannedFiles = $count
        rateLimitedRoutes = $allLimitedKeys.Count
        mutatingRoutes = $allMutatingKeys.Count
        missingLimits = $missingKeys.Count
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
