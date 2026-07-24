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

# Known model context windows (tokens)
$modelWindows = @{
    'gpt-4o' = 128000; 'gpt-4-turbo' = 128000; 'gpt-4' = 8192; 'gpt-3.5-turbo' = 16385
    'gpt-3.5-turbo-16k' = 16385; 'claude-3-opus' = 200000; 'claude-3-sonnet' = 200000
    'claude-3-haiku' = 200000; 'claude-3.5-sonnet' = 200000; 'gemini-pro' = 32768
    'gemini-1.5-pro' = 1048576; 'gemini-1.5-flash' = 1048576; 'llama-3-70b' = 8192
    'llama-3-8b' = 8192; 'mistral-large' = 32768; 'mixtral-8x7b' = 32768
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

    # Find LLM API call sites
    $callPatterns = @(
        '(?i)(openai|azure\.openai)\.[\w.]+\.(create|generate|chat|complete)',
        '(?i)(anthropic|bedrock)\.[\w.]+\.(messages|complete|generate)',
        '(?i)client\.(chat|complete|generate|messages)',
        '(?i)model\.(generate|predict|invoke|stream)',
        '(?i)(llm|chat_model|model)\.(invoke|predict|generate|stream)',
        '(?i)\.chat\.completions\.create'
    )

    $q = "['" + '"' + ']'
    $modelPatterns = @(
        "(?i)model\s*[:=]\s*$q([^$q]+)$q",
        "(?i)model_name\s*[:=]\s*$q([^$q]+)$q",
        "(?i)deployment_name\s*[:=]\s*$q([^$q]+)$q"
    )

    foreach ($cp in $callPatterns) {
        $matches = [regex]::Matches($content, $cp)
        foreach ($m in $matches) {
            $foundModel = 'unknown'
            foreach ($mp in $modelPatterns) {
                $modelMatch = [regex]::Match($content.Substring(0, [Math]::Min($m.Index + 500, $content.Length)), $mp)
                if ($modelMatch.Success) { $foundModel = $modelMatch.Groups[1].Value; break }
            }

            # Extract tokens settings near the call
            $nearby = $content.Substring([Math]::Max(0, $m.Index - 200), [Math]::Min($m.Length + 400, $content.Length - [Math]::Max(0, $m.Index - 200)))
            $maxTokens = $null
            if ($nearby -match '(?i)max_tokens\s*[:=]\s*(\d+)') { $maxTokens = [int]$matches[1] }

            # Estimate token counts
            $sysPromptMatch = [regex]::Match($nearby, "(?i)(system|role)\s*[:=]\s*$q([^$q]+)$q")
            $sysPromptLen = if ($sysPromptMatch.Success) { $sysPromptMatch.Groups[2].Value.Length } else { 0 }
            $estimatedInput = [Math]::Max(50, $sysPromptLen / 4)  # rough: ~4 chars/token

            # Detect context injection
            $hasExcessiveContext = $nearby -match '(?i)(full_document|entire_file|whole_content|all_results|search_results|document\.text|file\.content)'

            # Detect repetitive content
            $hasRepetitive = $false
            $msgPatterns = @([regex]::Matches($nearby, '(?i)("content":\s*"[^"]{50,})'))
            if ($msgPatterns.Count -gt 3) { $hasRepetitive = $true }

            # Context window
            $contextWindow = $null
            foreach ($kv in $modelWindows.GetEnumerator()) {
                if ($foundModel -match [regex]::Escape($kv.Key)) { $contextWindow = $kv.Value; break }
            }
            $hasTruncationRisk = $null -ne $contextWindow -and $null -ne $maxTokens -and $maxTokens -gt $contextWindow
            $hasTruncationRisk = $hasTruncationRisk -or ($null -ne $contextWindow -and $estimatedInput -gt $contextWindow * 0.9)

            # Efficiency classification
            $efficiency = 'efficient'
            if ($hasTruncationRisk) { $efficiency = 'critical' }
            elseif ($hasExcessiveContext -or $estimatedInput -gt 2000) { $efficiency = 'wasteful' }
            elseif ($hasRepetitive) { $efficiency = 'wasteful' }

            $callSites.Add([ordered]@{
                    file = $relPath
                    line = $m.Index
                    model = $foundModel
                    estimatedInputTokens = [int]$estimatedInput
                    estimatedOutputTokens = if ($null -ne $maxTokens) { $maxTokens } else { 500 }
                    maxTokens = $maxTokens
                    contextWindow = $contextWindow
                    hasTruncationRisk = $hasTruncationRisk
                    hasExcessiveContext = $hasExcessiveContext
                    hasRepetitiveContent = $hasRepetitive
                    efficiency = $efficiency
                })
        }
    }
}

$counts = @{ total = $callSites.Count; efficient = 0; wasteful = 0; critical = 0 }
foreach ($c in $callSites) {
    if ($counts.ContainsKey($c.efficiency)) { $counts[$c.efficiency]++ }
}

$result = [ordered]@{
    callSites = $callSites.ToArray()
    counts = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)
Write-Output "`n=== TOKEN-SCAN ==="
Write-Output "  Call sites found: $($callSites.Count)"
foreach ($key in ($counts.Keys | Where-Object { $_ -ne 'total' })) {
    Write-Output "  $key`: $($counts[$key])"
}
