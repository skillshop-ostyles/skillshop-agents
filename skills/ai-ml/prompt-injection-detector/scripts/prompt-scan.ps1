[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ps1,*.py,*.js,*.ts,*.jsx,*.tsx,*.rb,*.php,*.java,*.go,*.cs",

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

$extList = $Extensions -split ',' | ForEach-Object { $_.Trim() }
$excludeList = if ($Exclude) { $Exclude -split ',' | ForEach-Object { $_.Trim() } } else { @() }

# -- LLM API patterns --
$apiPatterns = @(
    @{ name = 'openai'; pattern = '(?i)(openai|chat\.completions\.create|completion\.create|/v1/chat/completions)' }
    @{ name = 'anthropic'; pattern = '(?i)(anthropic|messages\.create|/v1/messages)' }
    @{ name = 'gemini'; pattern = '(?i)(gemini|generateContent|generativelanguage|/v1beta/models)' }
    @{ name = 'langchain'; pattern = '(?i)(langchain|LLMChain|ChatPromptTemplate)' }
    @{ name = 'ollama'; pattern = '(?i)(ollama|/api/chat|/api/generate)' }
    @{ name = 'generic-llm'; pattern = '(?i)(model\.invoke|model\.predict|client\.complete|\.complete\s*\()' }
)

# -- Untrusted source patterns --
$untrustedSources = @(
    '(?i)\b(req\.(query|params|body|headers))\b',
    '(?i)\b(request\.(args|form|json|data|headers|query_string))\b',
    '(?i)\bc\.(req\.|env\.)\b',
    '(?i)\bprocess\.argv\b',
    '(?i)\bsys\.argv\b',
    '(?i)\$args\b',
    '(?i)\bos\.Args\b',
    '(?i)\bargv\b',
    '(?i)(readFile|Get-Content|file_get_contents|fread|fgets)\s*\(',
    '(?i)\binput\s*\(\b',
    '(?i)\bRead-Host\b',
    '(?i)\$_GET|\$_POST|\$_REQUEST|\$_SERVER',
    '(?i)\bresult\.\w+|row\.\w+|record\.\w+'
)

# -- Variable names considered potentially untrusted --
$untrustedVarNames = @(
    '(?i)^(dreamText|userText|input|message|content|body|data|text|query|arg|args|param|params|value|val|name|email|comment|feedback|prompt|userInput|user_msg|user_message)$'
)

# -- Guard patterns --
$guardPatterns = @(
    '(?i)INJECTION_GUARD|PROMPT_INJECTION|INSTRUCTION_SEPARATOR|CONTENT_DELIMITER',
    '(?i)ignore\s+(above|previous|following|all)\s+(instructions|commands)',
    '(?i)treat\s+(the\s+)?following\s+(as\s+)?(data|content|input|text)',
    '(?i)do\s+not\s+(follow|obey|execute|interpret)',
    '(?i)you\s+are\s+(an?\s+)?(AI|assistant|bot)\s+',
    '(?i)escape|sanitize|filter|purify|clean\s+input',
    '(?i)separator|delimiter|boundary',
    '(?i)(system|instructions?)\s*(:|are\s+above|follow)',
    '(?i)markdown.*code.*block|```',
    '(?i)wrap.*(user|input).*(in|with)'
)

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

function Get-Context {
    param([string[]]$Lines, [int]$LineIndex, [int]$Radius = 5)
    $start = [Math]::Max(0, $LineIndex - $Radius)
    $end = [Math]::Min($Lines.Length - 1, $LineIndex + $Radius)
    $ctx = @()
    for ($i = $start; $i -le $end; $i++) {
        $ctx += $Lines[$i]
    }
    return ($ctx -join "`n")
}

function Test-NearbyPattern {
    param([string[]]$Lines, [int]$LineIndex, [string[]]$Patterns, [int]$Radius = 10)
    $start = [Math]::Max(0, $LineIndex - $Radius)
    $end = [Math]::Min($Lines.Length - 1, $LineIndex + $Radius)
    $found = @()
    for ($i = $start; $i -le $end; $i++) {
        foreach ($p in $Patterns) {
            if ($Lines[$i] -match $p) {
                $found += "$p (line $($i+1))"
            }
        }
    }
    return ($found | Select-Object -Unique)
}

function Get-UsedVariables {
    param([string]$Content)
    $vars = @()
    # Template literal vars: ${...}
    $ms = [regex]::Matches($Content, '\$\{(\w+)\}')
    foreach ($m in $ms) { $vars += $m.Groups[1].Value }
    # String concat vars: + var +
    $ms2 = [regex]::Matches($Content, '["'']\s*\+\s*(\w+)\s*\+')
    foreach ($m in $ms2) { $vars += $m.Groups[1].Value }
    # Function call vars: fn(var) or fn(var1, var2)
    $ms3 = [regex]::Matches($Content, '(?i)(?:buildUserPrompt|buildPrompt|format|template)\s*\([^)]*(\w+)')
    foreach ($m in $ms3) { $vars += $m.Groups[1].Value }
    return ($vars | Select-Object -Unique)
}

function Test-IsUntrusted {
    param([string]$VarName, [string]$FileContent, [int]$LineIndex)
    if ($VarName -match '(?i)^(dreamText|userText|input|message|content|body|data|text|query|arg|args|param|params|value|val|name|email|comment|feedback|prompt|userInput|user_msg|user_message)$') { return $true }
    # Check if variable is assigned from untrusted source on nearby lines
    $lines = $FileContent -split "`n"
    $start = [Math]::Max(0, $LineIndex - 15)
    $end = [Math]::Min($lines.Length - 1, $LineIndex)
    for ($i = $start; $i -le $end; $i++) {
        if ($lines[$i] -match "(?i)(const|let|var)\s+$VarName\s*=\s*.+(req\.|request\.|process\.|Read-Host|input\(|argv|env\.|query|body|params|headers)") {
            return $true
        }
        if ($lines[$i] -match "(?i)`$$VarName\s*=\s*.+(req\.|request\.|Read-Host|`$env:|argv|input)") {
            return $true
        }
        if ($lines[$i] -match "(?i)$VarName\s*[:=]\s*.+(request\.|req\.|c\.|ctx\.)") {
            return $true
        }
    }
    return $false
}

$files = Get-SourceFiles -Dir $ProjectDir
$allFindings = @()
$allApiCalls = @()
$findingId = 0

foreach ($f in $files) {
    $rel = $f.FullName.Substring($ProjectDir.Length).TrimStart('\')
    $ext = $f.Extension.ToLower()

    try {
        $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
    } catch { continue }
    $lines = $content -split "`n"

    # Detect LLM API calls
    $apiHits = @()
    $apiLineMap = @{}
    foreach ($ap in $apiPatterns) {
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match $ap.pattern) {
                $apiHits += @{ provider = $ap.name; line = $i; text = $lines[$i] }
                if (-not $apiLineMap.ContainsKey($i)) { $apiLineMap[$i] = @() }
                $apiLineMap[$i] += $ap.name
            }
        }
    }

    if ($apiHits.Count -eq 0) { continue }

    foreach ($apiHit in $apiHits) {
        $lineIdx = $apiHit.line
        $provider = $apiHit.provider
        $apiCtx = Get-Context -Lines $lines -LineIndex $lineIdx

        # Collect lines that likely build the prompt (nearby)
        $promptLines = @()
        $promptSource = "unknown"
        for ($i = [Math]::Max(0, $lineIdx - 20); $i -le [Math]::Min($lines.Count - 1, $lineIdx + 5); $i++) {
            $promptLines += $lines[$i]
            if ($lines[$i] -match '(?i)(system_instruction|system_prompt|systemPrompt|SYSTEM_PROMPT)') { $promptSource = 'system' }
            if ($lines[$i] -match '(?i)(contents|content|messages|userPrompt|user_prompt|buildUserPrompt|buildPrompt)') { $promptSource = 'user' }
        }
        $promptContent = $promptLines -join "`n"

        # Extract variables used in prompt
        $varsInPrompt = Get-UsedVariables -Content $promptContent

        # Check for injection guards
        $guards = Test-NearbyPattern -Lines $lines -LineIndex $lineIdx -Patterns $guardPatterns

        # Identify untrusted variables
        $untrustedVars = @()
        foreach ($v in $varsInPrompt) {
            if (Test-IsUntrusted -VarName $v -FileContent $content -LineIndex $lineIdx) {
                $untrustedVars += $v
            }
        }

        # Determine severity
        $severity = "low"
        if ($promptSource -eq 'system' -and $untrustedVars.Count -gt 0 -and $guards.Count -eq 0) {
            $severity = "high"
        } elseif ($promptSource -eq 'user' -and $untrustedVars.Count -gt 0 -and $guards.Count -eq 0) {
            $severity = "high"
        } elseif ($untrustedVars.Count -gt 0 -and $guards.Count -eq 0) {
            $severity = "medium"
        } elseif ($untrustedVars.Count -gt 0 -and $guards.Count -gt 0) {
            $severity = "low"
        }

        $apiCall = @{
            file = $rel
            line = $lineIdx + 1
            provider = $provider
            promptSource = $promptSource
            untrustedVars = $untrustedVars
            hasGuard = ($guards.Count -gt 0)
        }
        $allApiCalls += $apiCall

        if ($untrustedVars.Count -gt 0 -or $promptSource -eq 'system') {
            $finding = @{
                id = $findingId
                file = $rel
                line = $lineIdx + 1
                apiProvider = $provider
                promptSource = $promptSource
                untrustedVars = $untrustedVars
                hasGuard = ($guards.Count -gt 0)
                guardType = if ($guards.Count -gt 0) { $guards[0] } else { "none" }
                severity = $severity
                context = $apiCtx
                remediation = if ($severity -eq 'high') {
                    "Untrusted data flows into $promptSource prompt. Add injection guard, separate instructions from data, validate input before prompt construction."
                } elseif ($severity -eq 'medium') {
                    "Consider adding or strengthening injection guard for $promptSource prompt."
                } else {
                    "Injection guard found. Verify it covers all untrusted variables."
                }
            }
            $allFindings += $finding
            $findingId++
        }
    }
}

# -- Stats --
$bySeverity = @{ high = 0; medium = 0; low = 0 }
foreach ($f in $allFindings) { $bySeverity[$f.severity]++ }

$uniqueFiles = @($allApiCalls | ForEach-Object { $_.file } | Select-Object -Unique)

$stats = @{
    totalFiles = $uniqueFiles.Count
    apiCalls = $allApiCalls.Count
    findings = $allFindings.Count
    high = $bySeverity.high
    medium = $bySeverity.medium
    low = $bySeverity.low
}

$output = @{
    findings = $allFindings
    apiCalls = $allApiCalls
    stats = $stats
}

$json = $output | ConvertTo-Json -Depth 5
Write-Output $json

# Console summary
Write-Output "=== Prompt Injection Scan Complete ==="
Write-Output "  Files with API calls: $($uniqueFiles.Count)"
Write-Output "  API call sites: $($allApiCalls.Count)"
Write-Output "  Findings: $($allFindings.Count)"
Write-Output "    high: $($bySeverity.high) | medium: $($bySeverity.medium) | low: $($bySeverity.low)"
if ($allFindings.Count -gt 0) {
    Write-Output "  Top risks:"
    $allFindings | Where-Object { $_.severity -eq 'high' } | ForEach-Object {
        Write-Output "    [$($_.severity)] $($_.file):$($_.line) - $($_.apiProvider) $($_.promptSource) prompt, vars: $($_.untrustedVars -join ',')"
    }
}
Write-Output ""
Write-Output "  Next step: run LLM analysis via SKILL.md steps"
