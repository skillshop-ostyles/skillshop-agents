[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,
    [string[]]$Extensions = @('py', 'ts', 'js', 'tsx', 'jsx', 'cs', 'go', 'rs', 'java', 'rb'),
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

function Test-Excluded($fullPath) {
    $rel = $fullPath.Substring($root.Length).TrimStart('\', '/')
    foreach ($part in ($rel -split '[\\/]')) {
        if ($excludeSet -contains $part.ToLower()) { return $true }
    }
    return $false
}

$providersPatterns = @{
    'openai' = @('openai', 'AzureOpenAI', 'ChatOpenAI')
    'anthropic' = @('anthropic', 'Anthropic', 'ChatAnthropic')
    'cohere' = @('cohere', 'Cohere')
    'huggingface' = @('huggingface', 'HuggingFace', 'HuggingFaceHub')
    'google' = @('google', 'GooglePalm', 'ChatGooglePalm', 'VertexAI')
    'aws' = @('bedrock', 'Bedrock', 'SageMaker')
    'ollama' = @('ollama', 'Ollama')
    'generic' = @('model\.(generate|invoke|predict)', 'llm\.(invoke|predict)')
}

$callSites = New-Object System.Collections.Generic.List[object]
$allFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
    Where-Object { -not (Test-Excluded $_.FullName) }

foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    $content = $lines -join "`n"
    $lineArray = $lines

    foreach ($provider in $providersPatterns.Keys) {
        foreach ($pattern in $providersPatterns[$provider]) {
            $matches = [regex]::Matches($content, [regex]::Escape($pattern))
            if ($matches.Count -eq 0) { continue }

            # Find the line number for each match
            foreach ($m in $matches) {
                # Find approximated line number
                $lineNum = 1
                $charCount = 0
                for ($i = 0; $i -lt $lineArray.Count; $i++) {
                    $charCount += $lineArray[$i].Length + 2
                    if ($charCount -gt $m.Index) { $lineNum = $i + 1; break }
                }

                # Check observability within nearby lines (window of +/- 5 lines)
                $windowStart = [Math]::Max(0, $lineNum - 6)
                $windowEnd = [Math]::Min($lineArray.Count - 1, $lineNum + 4)
                $nearbyLines = $lineArray[$windowStart..$windowEnd] -join "`n"

                $hasErrorHandling = $nearbyLines -match '(?i)(try|catch|\.catch|onError|error_handler|except\s|Error|errorCallback)'
                $hasLogging = $nearbyLines -match '(?i)(logger\.|console\.log|logging\.|log\.info|log\.error|log\.warn|log\.debug|audit\.|tracer\.)'
                $hasTimeout = $nearbyLines -match '(?i)(timeout|request_timeout|max_retries|retry|backoff|max_wait)'
                $hasCostTracking = $nearbyLines -match '(?i)(cost|price|token_usage|usage\.total_tokens|prompt_tokens|completion_tokens|pricing)'
                $hasLatencyTracking = $nearbyLines -match '(?i)(latency|duration|elapsed|performance\.now|timing|response_time|measure|metrics\.)'

                # Gap score: 0 = fully observed, 5 = blind
                $gapScore = 0
                if (-not $hasErrorHandling) { $gapScore++ }
                if (-not $hasLogging) { $gapScore++ }
                if (-not $hasTimeout) { $gapScore++ }

                $classification = 'observed'
                if ($gapScore -ge 2) { $classification = 'blind' }
                elseif ($gapScore -ge 1) { $classification = 'partially-observed' }

                $callSites.Add([ordered]@{
                        file = $relPath
                        line = $lineNum
                        provider = $provider
                        hasErrorHandling = $hasErrorHandling
                        hasLogging = $hasLogging
                        hasTimeout = $hasTimeout
                        hasCostTracking = $hasCostTracking
                        hasLatencyTracking = $hasLatencyTracking
                        gapScore = $gapScore
                        classification = $classification
                    })
            }
        }
    }
}

$counts = @{ total = $callSites.Count; observed = 0; 'partially-observed' = 0; blind = 0 }
foreach ($c in $callSites) {
    if ($counts.ContainsKey($c.classification)) { $counts[$c.classification]++ }
}

$result = [ordered]@{
    callSites = $callSites.ToArray()
    counts = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)
Write-Output "`n=== OBS-SCAN ==="
Write-Output "  Call sites found: $($callSites.Count)"
foreach ($key in ($counts.Keys | Where-Object { $_ -ne 'total' })) {
    Write-Output "  $key`: $($counts[$key])"
}
