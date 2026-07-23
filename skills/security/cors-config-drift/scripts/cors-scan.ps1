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

# Header-based CORS patterns
$headerPatterns = @(
    @{ regex='Access-Control-Allow-Origin'; corsType='header' },
    @{ regex='Access-Control-Allow-Credentials'; corsType='header' },
    @{ regex='Access-Control-Allow-Methods'; corsType='header' },
    @{ regex='Access-Control-Allow-Headers'; corsType='header' },
    @{ regex='Access-Control-Max-Age'; corsType='header' },
    @{ regex='Access-Control-Expose-Headers'; corsType='header' }
)

# Middleware/decorator patterns (cors(), @cross_origin)
$middlewarePatterns = @(
    @{ regex='cors\s*\(\s*\{'; corsType='middleware' },
    @{ regex='cors\s*\(\s*\)'; corsType='middleware' },
    @{ regex='\.use\s*\(\s*cors\s*\('; corsType='middleware' },
    @{ regex='@cross_origin'; corsType='middleware' },
    @{ regex='CrossOrigin\s*\(.*\)'; corsType='middleware' },
    @{ regex='@CrossOrigin'; corsType='middleware' }
)

# OPTIONS handler patterns
$optionsPatterns = @(
    @{ regex='app\.options\s*\(\s*["\x27]\*["\x27]'; corsType='handler' },
    @{ regex='app\.options\s*\(\s*["\x27][^"\x27]+["\x27]'; corsType='handler' },
    @{ regex='router\.options\s*\(\s*["\x27]\*["\x27]'; corsType='handler' },
    @{ regex='router\.options\s*\(\s*["\x27][^"\x27]+["\x27]'; corsType='handler' }
)

# Config-object keys inside cors() or similar
$configPatterns = @(
    @{ regex='origin\s*:\s*["\x27]\*["\x27]'; configKey='origin'; configVal='*' },
    @{ regex='origin\s*:\s*true'; configKey='origin'; configVal='true' },
    @{ regex='origin\s*:\s*["\x27](https?://[^"\x27]+)["\x27]'; configKey='origin'; configVal='specific' },
    @{ regex='origin\s*:\s*\[.*\]'; configKey='origin'; configVal='array' },
    @{ regex='credentials\s*:\s*true'; configKey='credentials'; configVal='true' },
    @{ regex='credentials\s*:\s*false'; configKey='credentials'; configVal='false' },
    @{ regex='allowMultipleOrigins\s*:\s*true'; configKey='allowMultipleOrigins'; configVal='true' },
    @{ regex='methods\s*:\s*["\x27]\*["\x27]'; configKey='methods'; configVal='*' },
    @{ regex='allowedHeaders\s*:\s*["\x27]\*["\x27]'; configKey='allowedHeaders'; configVal='*' },
    @{ regex='exposedHeaders\s*:\s*["\x27]\*["\x27]'; configKey='exposedHeaders'; configVal='*' }
)

# Route-grep: extract route path from same/adjacent line
$routePattern = '(?:get|post|put|patch|delete|all|use)\s*\(\s*["\x27]([^"\x27]+)["\x27]'

$findings = @()
$linesScanned = 0
$counts = @{
    header = 0
    middleware = 0
    handler = 0
    config = 0
}

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
        $lines = $content -split "`n"
        $linesScanned += $lines.Count
        for ($li = 0; $li -lt $lines.Count; $li++) {
            $ln = $lines[$li]

            # Detect header CORS statements
            foreach ($r in $headerPatterns) {
                if ($ln -match $r.regex) {
                    $originVal = ''
                    $credVal = $false
                    $wildcard = $false
                    $dangerous = $false
                    if ($ln -match '["\x27](\*|https?://[^"\x27]+)["\x27]') {
                        $originVal = $matches[1]
                        if ($originVal -eq '*') { $wildcard = $true }
                    }
                    if ($ln -match 'Access-Control-Allow-Credentials') {
                        if ($ln -match 'true') { $credVal = $true }
                    }
                    if ($wildcard -and $credVal) { $dangerous = $true }

                    # Extract route from context (previous/current line)
                    $route = ''
                    if ($li -gt 0 -and $lines[$li - 1] -match $routePattern) { $route = $matches[1] }
                    if ($ln -match $routePattern) { $route = $matches[1] }

                    $counts.header++
                    $findings += @{
                        file = $rel
                        line = $li + 1
                        corsType = 'header'
                        origin = $originVal
                        credentials = $credVal
                        route = $route
                        wildcard = $wildcard
                        dangerous = $dangerous
                        lineContent = ($ln.Trim() -replace '\s+', ' ')
                    }
                }
            }

            # Detect middleware/decorator CORS
            foreach ($r in $middlewarePatterns) {
                if ($ln -match $r.regex) {
                    $originVal = ''
                    $credVal = $false
                    $wildcard = $false
                    $dangerous = $false

                    # Parse config object on same line or next lines
                    if ($ln -match 'origin\s*:\s*["\x27]\*["\x27]') { $originVal = '*'; $wildcard = $true }
                    elseif ($ln -match 'origin\s*:\s*true') { $originVal = 'true' }
                    elseif ($ln -match 'origin\s*:\s*["\x27]([^"\x27]+)["\x27]') { $originVal = $matches[1] }

                    if ($ln -match 'credentials\s*:\s*true') { $credVal = $true }

                    if ($wildcard -and $credVal) { $dangerous = $true }

                    # Check if this line also has a route binding
                    $route = ''
                    if ($ln -match $routePattern) { $route = $matches[1] }

                    $counts.middleware++
                    $findings += @{
                        file = $rel
                        line = $li + 1
                        corsType = 'middleware'
                        origin = $originVal
                        credentials = $credVal
                        route = $route
                        wildcard = $wildcard
                        dangerous = $dangerous
                        lineContent = ($ln.Trim() -replace '\s+', ' ')
                    }
                }
            }

            # Detect OPTIONS handlers
            foreach ($r in $optionsPatterns) {
                if ($ln -match $r.regex) {
                    $originVal = ''
                    $credVal = $false
                    $wildcard = $false
                    $dangerous = $false

                    if ($ln -match 'origin\s*:\s*["\x27]\*["\x27]') { $originVal = '*'; $wildcard = $true }
                    elseif ($ln -match 'origin\s*:\s*true') { $originVal = 'true' }
                    if ($ln -match 'credentials\s*:\s*true') { $credVal = $true }
                    if ($wildcard -and $credVal) { $dangerous = $true }

                    $route = ''
                    if ($ln -match $routePattern) { $route = $matches[1] }

                    $counts.handler++
                    $findings += @{
                        file = $rel
                        line = $li + 1
                        corsType = 'handler'
                        origin = $originVal
                        credentials = $credVal
                        route = $route
                        wildcard = $wildcard
                        dangerous = $dangerous
                        lineContent = ($ln.Trim() -replace '\s+', ' ')
                    }
                }
            }

            # Detect config-object keys (supplemental — not double-counted)
            foreach ($r in $configPatterns) {
                if ($ln -match $r.regex) {
                    $counts.config++
                    # Attach route if present
                    $route = ''
                    if ($ln -match $routePattern) { $route = $matches[1] }
                    $findings += @{
                        file = $rel
                        line = $li + 1
                        corsType = 'config-key'
                        origin = $r.configVal
                        credentials = ($r.configKey -eq 'credentials' -and $r.configVal -eq 'true')
                        route = $route
                        wildcard = ($r.configVal -eq '*')
                        dangerous = ($r.configKey -eq 'origin' -and $r.configVal -eq '*')
                        lineContent = ($ln.Trim() -replace '\s+', ' ')
                    }
                }
            }
        }
    }
}

Write-Output "=== CORS Config Scan Complete ==="
$fileSet = @($findings | ForEach-Object { $_.file } | Select-Object -Unique)
$dangerousSet = @($findings | Where-Object { $_.dangerous })
Write-Output "  Files: $($fileSet.Count)"
Write-Output "  Lines scanned: $linesScanned"
Write-Output "  Total findings: $($findings.Count)"
Write-Output "  header: $($counts.header)"
Write-Output "  middleware: $($counts.middleware)"
Write-Output "  handler: $($counts.handler)"
Write-Output "  config-key: $($counts.config)"
Write-Output "  Dangerous (credentials+wildcard): $($dangerousSet.Count)"

$result = @{
    findings = $findings
    counts = @{
        files = $fileSet.Count
        totalFindings = $findings.Count
        header = $counts.header
        middleware = $counts.middleware
        handler = $counts.handler
        configKey = $counts.config
        dangerous = $dangerousSet.Count
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
