[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('ts', 'tsx', 'js', 'jsx', 'py', 'cs', 'go', 'rs', 'java', 'php', 'rb', 'vue'),
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

$findings = New-Object System.Collections.Generic.List[object]

# Log patterns by language/framework
$logPatterns = @(
    '(?i)(console|logger|log)\.\s*(log|info|warn|error|debug|trace|fatal)\s*\(',
    '(?i)(Log\.|Logger\.|_logger\.)\s*(Information|Warning|Error|Debug|Trace|Critical)\s*\(',
    '(?i)(fmt\.Print|fmt\.Println|fmt\.Errorf|log\.Print|log\.Fatalf)',
    '(?i)(Rails\.logger|logger\.(info|warn|error|debug))',
    '(?i)(zap\.(L|S)\.|logrus\.|log\.)',
    '(?i)(print|println|printf)\s*\(',
    '(?i)System\.Console\.(WriteLine|Write|Out\.Write)'
)

$counts = @{ total = 0; hasTemplate = 0; hasCorrelationId = 0; isStructured = 0; isErrorPath = 0; hasPiiRisk = 0 }
$levels = @{}

$allFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
    Where-Object { -not (Test-ExcludedPath $_.FullName) }

foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = [string]$lines[$i]
        $lineNum = $i + 1

        foreach ($pat in $logPatterns) {
            if ($line -match $pat) {
                $level = 'info'
                if ($line -match '(?i)(error|fatal|critical)') { $level = 'error' }
                elseif ($line -match '(?i)warn') { $level = 'warn' }
                elseif ($line -match '(?i)debug|trace') { $level = 'debug' }

                if (-not $levels.ContainsKey($level)) { $levels[$level] = 0 }
                $levels[$level]++
                $counts.total++

                # Check for structured logging (template with placeholders)
                $hasTemplate = $line -match '\{[\w]+\}' -or $line -match '%[\w.]'

                # Check for correlation ID / request ID
                $hasCorrelationId = $line -match '(?i)(correlation|requestId|traceId|spanId|transactionId)'

                # Check if in error handling path (catch/onerror/finally block)
                $isErrorPath = $line -match '(?i)(catch|on.?error|exception|fail|finally)'

                # Check for PII risk (emails, SSN, credit cards, API keys)
                $hasPiiRisk = $line -match '[\w\.-]+@[\w\.-]+\.\w+' -or
                $line -match '\b\d{3}-\d{2}-\d{4}\b' -or
                $line -match '\b(4\d{3}|5\d{3}|6\d{3})\d{12,15}\b' -or
                ($line -match '(?i)(api[_-]?key|secret|password|token|credential)=')

                if ($hasTemplate) { $counts.hasTemplate++ }
                if ($hasCorrelationId) { $counts.hasCorrelationId++ }
                if ($isErrorPath) { $counts.isErrorPath++ }
                if ($hasPiiRisk) { $counts.hasPiiRisk++ }

                # Determine if structured (has template + context fields)
                $isStructured = $hasTemplate -or ($line -match '\b\w+Id\b' -and $line -notmatch '\+\s*[''"]')
                if ($isStructured) { $counts.isStructured++ }

                $findings.Add([ordered]@{
                        file             = $relPath
                        line             = $lineNum
                        level            = $level
                        text             = $line.Trim()
                        hasTemplate      = $hasTemplate
                        hasCorrelationId = $hasCorrelationId
                        isStructured     = $isStructured
                        isErrorPath      = $isErrorPath
                        hasPiiRisk       = $hasPiiRisk
                    })
                break
            }
        }
    }
}

$result = [ordered]@{
    logStatements = $findings.ToArray()
    counts        = $counts
    levels        = $levels
    scannedFiles  = $allFiles.Count
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== LOG-HARVEST ==="
Write-Output "  Files scanned: $($allFiles.Count)"
Write-Output "  Log statements found: $($counts.total)"
Write-Output "  Structured: $($counts.isStructured)  ($(if ($counts.total -gt 0) { [math]::Round($counts.isStructured/$counts.total*100) } else { 0 })%)"
Write-Output "  With correlation ID: $($counts.hasCorrelationId)"
Write-Output "  PII risk: $($counts.hasPiiRisk)"
