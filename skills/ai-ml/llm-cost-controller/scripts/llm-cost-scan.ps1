[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [int]$MonthlyCallEstimate = 100000,

    [string]$Exclude = ""
)

$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Host "ERROR: Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

$extList = @('*.ps1','*.py','*.js','*.ts','*.jsx','*.tsx','*.rb','*.php','*.java','*.go','*.cs')
$excludeList = if ($Exclude) { $Exclude -split ',' | ForEach-Object { $_.Trim() } } else { @() }

# -- Pricing (per 1K tokens, input/output) --
$pricing = @{
    'gpt-4o' = @{ input = 2.50; output = 10.00 }
    'gpt-4o-mini' = @{ input = 0.15; output = 0.60 }
    'gpt-4' = @{ input = 30.00; output = 60.00 }
    'gpt-4-turbo' = @{ input = 10.00; output = 30.00 }
    'gpt-3.5-turbo' = @{ input = 0.50; output = 1.50 }
    'claude-3-5-sonnet' = @{ input = 3.00; output = 15.00 }
    'claude-3-opus' = @{ input = 15.00; output = 75.00 }
    'claude-3-haiku' = @{ input = 0.25; output = 1.25 }
    'claude-2' = @{ input = 8.00; output = 24.00 }
    'gemini-1.5-pro' = @{ input = 1.25; output = 5.00 }
    'gemini-1.5-flash' = @{ input = 0.075; output = 0.30 }
    'gemini-2.0-flash' = @{ input = 0.10; output = 0.40 }
    'gemini-2.0-pro' = @{ input = 2.00; output = 8.00 }
}

# -- API patterns --
$apiPatterns = @(
    @{ name = 'openai'; pattern = '(?i)(openai|chat\.completions\.create|completion\.create)' }
    @{ name = 'anthropic'; pattern = '(?i)(anthropic|messages\.create)' }
    @{ name = 'gemini'; pattern = '(?i)(gemini|generateContent|generativelanguage)' }
    @{ name = 'langchain'; pattern = '(?i)(langchain|invoke|LLMChain|ChatPromptTemplate)' }
    @{ name = 'ollama'; pattern = '(?i)(ollama|/api/chat|/api/generate)' }
    @{ name = 'generic'; pattern = '(?i)(model\.invoke|model\.predict|\.complete\s*\()' }
)

# -- Model regex patterns --
$modelPatterns = @(
    '(?i)model\s*[:=]\s*[''"]([^''"]+)[''"]',
    '(?i)model\s*[:=]\s*`([^`]+)`',
    '(?i)model\s*:\s*(\w+)'
)

# -- Parameter patterns --
$maxTokensPattern = '(?i)max_tokens\s*[:=]\s*(\d+)'
$temperaturePattern = '(?i)temperature\s*[:=]\s*([\d.]+)'
$topPPattern = '(?i)top_p\s*[:=]\s*([\d.]+)'
$retryPattern = '(?i)(maxRetries|retry|attempts)\s*[:=]\s*(\d+)'

function Get-SourceFiles {
    param([string]$Dir)
    $files = @()
    foreach ($ext in $extList) {
        $found = Get-ChildItem -Path $Dir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue
        foreach ($f in $found) {
            $skip = $false
            foreach ($ex in $excludeList) {
                if ($f.FullName -like "*$ex*") { $skip = $true; break }
            }
            if (-not $skip -and $f.FullName -notlike "*\node_modules\*" -and $f.FullName -notlike "*\.git\*" -and $f.FullName -notlike "*\venv\*" -and $f.FullName -notlike "*\__pycache__\*") {
                $files += $f
            }
        }
    }
    return $files
}

function Get-ContextBlock {
    param([string[]]$Lines, [int]$LineIndex, [int]$Radius = 3)
    $start = [Math]::Max(0, $LineIndex - $Radius)
    $end = [Math]::Min($Lines.Length - 1, $LineIndex + $Radius)
    return (($lines[$start..$end]) -join "`n")
}

function Test-InLoop {
    param([string[]]$Lines, [int]$LineIndex, [int]$Radius = 20)
    $start = [Math]::Max(0, $LineIndex - $Radius)
    for ($i = $start; $i -lt $LineIndex; $i++) {
        if ($Lines[$i] -match '(?i)\b(for|while|forEach|map)\s*\(') { return $true }
        if ($Lines[$i] -match '(?i)\bfor\s+\w+\s+in\b') { return $true }
    }
    return $false
}

function Test-HasCachingNearby {
    param([string[]]$Lines, [int]$LineIndex, [int]$Radius = 15)
    $start = [Math]::Max(0, $LineIndex - $Radius)
    $end = [Math]::Min($Lines.Length - 1, $LineIndex + $Radius)
    for ($i = $start; $i -le $end; $i++) {
        if ($Lines[$i] -match '(?i)(cache|memoize|kv\.|redis|Map\(|new Map|WeakMap|memo)') { return $true }
    }
    return $false
}

function Get-ModelKey {
    param([string]$ModelName)
    $m = $ModelName.ToLower().Trim()
    # Normalize model names
    if ($m -match 'gpt-4o-mini') { return 'gpt-4o-mini' }
    if ($m -match 'gpt-4o') { return 'gpt-4o' }
    if ($m -match 'gpt-4-turbo') { return 'gpt-4-turbo' }
    if ($m -match 'gpt-4') { return 'gpt-4' }
    if ($m -match 'gpt-3.5') { return 'gpt-3.5-turbo' }
    if ($m -match 'claude-3-5-sonnet') { return 'claude-3-5-sonnet' }
    if ($m -match 'claude-3-opus') { return 'claude-3-opus' }
    if ($m -match 'claude-3-haiku') { return 'claude-3-haiku' }
    if ($m -match 'claude-2') { return 'claude-2' }
    if ($m -match 'gemini.*1\.5.*pro') { return 'gemini-1.5-pro' }
    if ($m -match 'gemini.*1\.5.*flash') { return 'gemini-1.5-flash' }
    if ($m -match 'gemini.*2\.0.*flash|gemini-3\.5-flash') { return 'gemini-2.0-flash' }
    if ($m -match 'gemini.*2\.0.*pro') { return 'gemini-2.0-pro' }
    if ($m -match 'gemini') { return 'gemini-1.5-flash' }
    return $null
}

function Estimate-Cost {
    param([string]$ModelKey, [int]$MaxTokens, [int]$MonthlyEstimate)
    if (-not $pricing.ContainsKey($ModelKey)) { return @{ perCall = 0; monthly = 0 } }
    $p = $pricing[$ModelKey]
    $estTokens = if ($MaxTokens -gt 0) { $MaxTokens } else { 500 }
    $inputCost = ($estTokens / 1000) * $p.input
    $outputCost = ($estTokens / 1000) * $p.output
    $perCall = $inputCost + $outputCost
    $monthly = $perCall * $MonthlyEstimate
    return @{ perCall = [Math]::Round($perCall, 4); monthly = [Math]::Round($monthly, 2) }
}

$files = Get-SourceFiles -Dir $ProjectDir
$allFindings = @()
$allCalls = @()
$findingId = 0

foreach ($f in $files) {
    $rel = $f.FullName.Substring($ProjectDir.Length).TrimStart('\')

    try {
        $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
    } catch { continue }
    $lines = $content -split "`n"

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $matchedApi = $null
        foreach ($ap in $apiPatterns) {
            if ($lines[$i] -match $ap.pattern) { $matchedApi = $ap; break }
        }
        if (-not $matchedApi) { continue }

        # Extract model
        $modelKey = $null
        $modelName = "unknown"
        for ($j = [Math]::Max(0, $i - 3); $j -le [Math]::Min($lines.Count - 1, $i + 3); $j++) {
            foreach ($mp in $modelPatterns) {
                if ($lines[$j] -match $mp) {
                    $modelName = $matches[1]
                    $modelKey = Get-ModelKey -ModelName $modelName
                    break
                }
            }
            if ($modelKey) { break }
        }

        # Extract parameters from nearby lines
        $maxTokens = 0
        $temperature = $null
        $hasRetryBackoff = $false
        for ($j = [Math]::Max(0, $i - 5); $j -le [Math]::Min($lines.Count - 1, $i + 3); $j++) {
            if ($lines[$j] -match $maxTokensPattern) { $maxTokens = [int]$matches[1] }
            if ($lines[$j] -match $temperaturePattern) { $temperature = [double]$matches[1] }
            if ($lines[$j] -match $retryPattern) { $hasRetryBackoff = $true }
        }

        $inLoop = Test-InLoop -Lines $lines -LineIndex $i
        $hasCache = Test-HasCachingNearby -Lines $lines -LineIndex $i
        $cost = Estimate-Cost -ModelKey $modelKey -MaxTokens $maxTokens -MonthlyEstimate $MonthlyCallEstimate

        $call = @{
            file = $rel
            line = $i + 1
            provider = $matchedApi.name
            model = $modelName
            modelKey = $modelKey
            maxTokens = $maxTokens
            temperature = $temperature
            estimatedCostPerCall = $cost.perCall
        }
        $allCalls += $call

        # -- Anti-pattern checks --

        # 1. Expensive model for simple task
        if ($modelKey -match 'gpt-4$|claude-3-opus|claude-2') {
            $ctx = Get-ContextBlock -Lines $lines -LineIndex $i
            $allFindings += @{
                id = $findingId; check = 'expensive-model'; severity = 'high'
                file = $rel; line = $i + 1; model = $modelName
                context = $ctx
                detail = "Using high-cost model $modelName. Consider gpt-4o-mini or claude-3-haiku."
                estimatedMonthlySavings = "`$$([Math]::Round($cost.monthly * 0.8, 0))"
            }
            $findingId++
        }

        # 2. No max_tokens limit
        if ($maxTokens -eq 0 -and $modelKey) {
            $ctx = Get-ContextBlock -Lines $lines -LineIndex $i
            $allFindings += @{
                id = $findingId; check = 'no-max-tokens'; severity = 'high'
                file = $rel; line = $i + 1; model = $modelName
                context = $ctx
                detail = "No max_tokens limit set. Output could be unbounded."
                estimatedMonthlySavings = "varies"
            }
            $findingId++
        }

        # 3. High temperature
        if ($temperature -and $temperature -ge 1.0) {
            $ctx = Get-ContextBlock -Lines $lines -LineIndex $i
            $allFindings += @{
                id = $findingId; check = 'high-temperature'; severity = 'medium'
                file = $rel; line = $i + 1; model = $modelName
                context = $ctx
                detail = "Temperature $temperature >= 1.0 increases randomness and output length."
                estimatedMonthlySavings = "varies"
            }
            $findingId++
        }

        # 4. No retry backoff
        if (-not $hasRetryBackoff) {
            $ctx = Get-ContextBlock -Lines $lines -LineIndex $i
            $allFindings += @{
                id = $findingId; check = 'no-retry-backoff'; severity = 'medium'
                file = $rel; line = $i + 1; model = $modelName
                context = $ctx
                detail = "No retry backoff detected. Retries without backoff increase cost under load."
                estimatedMonthlySavings = "varies"
            }
            $findingId++
        }

        # 6. Batchable calls in loop
        if ($inLoop) {
            $ctx = Get-ContextBlock -Lines $lines -LineIndex $i
            $allFindings += @{
                id = $findingId; check = 'batchable-calls'; severity = 'medium'
                file = $rel; line = $i + 1; model = $modelName
                context = $ctx
                detail = "LLM call inside loop. Consider batching requests."
                estimatedMonthlySavings = "varies"
            }
            $findingId++
        }

        # 5. No caching
        if (-not $hasCache) {
            $ctx = Get-ContextBlock -Lines $lines -LineIndex $i
            $allFindings += @{
                id = $findingId; check = 'no-caching'; severity = 'medium'
                file = $rel; line = $i + 1; model = $modelName
                context = $ctx
                detail = "No caching detected. Repeated identical calls incur full cost each time."
                estimatedMonthlySavings = "varies"
            }
            $findingId++
        }

        # 8. Large context / streaming
        if ($modelName -match '32k|128k|200k|1m|1M') {
            $ctx = Get-ContextBlock -Lines $lines -LineIndex $i
            $allFindings += @{
                id = $findingId; check = 'large-context'; severity = 'low'
                file = $rel; line = $i + 1; model = $modelName
                context = $ctx
                detail = "Large context window model used. Consider if full context is needed."
                estimatedMonthlySavings = "varies"
            }
            $findingId++
        }
    }
}

# -- Deduplicate findings per check per file --
$seen = @{}
$deduped = @()
foreach ($f in $allFindings) {
    $key = "$($f.file):$($f.check)"
    if (-not $seen.ContainsKey($key)) {
        $seen[$key] = $true
        $deduped += $f
    }
}
$allFindings = $deduped

# -- Stats --
$bySeverity = @{ high = 0; medium = 0; low = 0 }
$byCheck = @{}
$totalMonthlyCost = 0
foreach ($f in $allFindings) {
    $bySeverity[$f.severity]++
    if (-not $byCheck.ContainsKey($f.check)) { $byCheck[$f.check] = 0 }
    $byCheck[$f.check]++
}
foreach ($c in $allCalls) {
    if ($c.estimatedCostPerCall) { $totalMonthlyCost += $c.estimatedCostPerCall * $MonthlyCallEstimate }
}

$uniqueFiles = @($allCalls | ForEach-Object { $_.file } | Select-Object -Unique)

$stats = @{
    totalApiCalls = $allCalls.Count
    files = $uniqueFiles.Count
    findings = $allFindings.Count
    high = $bySeverity.high
    medium = $bySeverity.medium
    low = $bySeverity.low
    estimatedMonthlyCost = "`$$([Math]::Round($totalMonthlyCost, 2))"
    estimatedSavings = "varies"
    byCheck = $byCheck
}

$output = @{
    findings = $allFindings
    apiCalls = $allCalls
    stats = $stats
}

$json = $output | ConvertTo-Json -Depth 5
Write-Output $json

# Console summary
Write-Output "=== LLM Cost Control Scan Complete ==="
Write-Output "  Files with API calls: $($uniqueFiles.Count)"
Write-Output "  Total API calls: $($allCalls.Count)"
Write-Output "  Est. monthly cost: `$$([Math]::Round($totalMonthlyCost, 2)) (at $MonthlyCallEstimate calls/mo)"
Write-Output "  Findings: $($allFindings.Count)"
Write-Output "    high: $($bySeverity.high) | medium: $($bySeverity.medium) | low: $($bySeverity.low)"
foreach ($c in ($byCheck.Keys | Sort-Object)) {
    Write-Output "    $c : $($byCheck[$c])"
}
Write-Output ""
Write-Output "  Next step: run LLM analysis via SKILL.md steps"
