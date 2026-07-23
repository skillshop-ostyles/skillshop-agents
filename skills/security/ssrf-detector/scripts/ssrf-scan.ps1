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

# --------------------------------------------------------------------
# SSRF SINK patterns: detect outbound HTTP call lines.
# Each pattern matches the function call so we can flag the line.
# --------------------------------------------------------------------
$sinkPatterns = @(
    @{ regex='\bfetch\s*\(';                          sink='fetch' }
    @{ regex='\baxios\s*\.\s*(?:get|post|put|patch|delete|request)\s*\('; sink='axios' }
    @{ regex='\baxios\s*\(\s*\{';                     sink='axios' }
    @{ regex='\bgot\s*\(';                            sink='got' }
    @{ regex='\brequest\s*\(';                        sink='request' }
    @{ regex='\bhttp\s*\.\s*(?:get|request)\s*\(';    sink='http' }
    @{ regex='\bsuperagent\s*\.\s*(?:get|post|put|patch|delete|query)\s*\('; sink='superagent' }
    @{ regex='\breq\s*\.\s*(?:get|post|put|patch|delete)\s*\('; sink='request-js' }
    @{ regex='\bInvoke-RestMethod\b';                  sink='Invoke-RestMethod' }
    @{ regex='\bInvoke-WebRequest\b';                  sink='Invoke-WebRequest' }
    @{ regex='\brequests\s*\.\s*(?:get|post|put|patch|delete|request)\s*\('; sink='python-requests' }
    @{ regex='\bHttpClient\s*\.\s*(?:GetAsync|PostAsync|PutAsync|DeleteAsync|SendAsync)\s*\('; sink='dotnet-httpclient' }
)

# --------------------------------------------------------------------
# URL SOURCE patterns: variables/expressions that carry user-controlled
# input. We match these on the same line or nearby.
# --------------------------------------------------------------------
$sourcePatterns = @(
    'req\.body\.url', 'req\.body\.image', 'req\.body\.link', 'req\.body\.target',
    'req\.body\.endpoint', 'req\.body\.redirect', 'req\.body\.callback',
    'req\.body\.webhook', 'req\.body\.avatar', 'req\.body\.profile', 'req\.body\.source',
    'req\.query\.url', 'req\.query\.link', 'req\.query\.target', 'req\.query\.endpoint',
    'req\.query\.redirect', 'req\.query\.callback', 'req\.query\.webhook',
    'req\.query\.image', 'req\.query\.avatar', 'req\.query\.profile', 'req\.query\.source',
    'req\.params\.url', 'req\.params\.target', 'req\.params\.link', 'req\.params\.endpoint',
    'request\.body\.url', 'request\.body\.image', 'request\.body\.link',
    'event\.body\.url', 'event\.body\.endpoint', 'event\.body\.callback', 'event\.body\.webhook',
    'context\.args\.url', 'context\.args\.endpoint'
)

# Variable name suffixes that hint at user-controlled URL (for fallback when
# no explicit source pattern matches).
$varHintPattern = '\b(url|uri|link|target|endpoint|redirect|callback|webhook|image|avatar|profile|source)\b'

# --------------------------------------------------------------------
# VALIDATION heuristics: checks done on the URL before calling the sink.
# --------------------------------------------------------------------
$validationHeuristics = @(
    @{ regex='new\s+URL\s*\(';                        type='url-parse' }
    @{ regex='url\.parse\s*\(';                       type='url-parse' }
    @{ regex='allowlist\s*\.\s*includes\s*\(';        type='hostname-allowlist' }
    @{ regex='whitelist\s*\.\s*includes\s*\(';        type='hostname-allowlist' }
    @{ regex='allowedHosts\s*\.\s*includes\s*\(';     type='hostname-allowlist' }
    @{ regex='allowedHosts\s*\.\s*has\s*\(';          type='hostname-allowlist' }
    @{ regex="\.startsWith\s*\(\s*['`"']https://['`"']?\s*\)"; type='scheme-validation' }
    @{ regex="\.startsWith\s*\(\s*['`"']https?:['`"']?\s*\)"; type='scheme-validation' }
    @{ regex="\.startsWith\s*\(\s*['`"']http://['`"']?\s*\)"; type='scheme-validation' }
    @{ regex="!\.startsWith\s*\(\s*['`"']http:";    type='scheme-validation' }
    @{ regex='169\.254';                               type='metadata-ip-block' }
    @{ regex='127\.0\.0\.1';                           type='metadata-ip-block' }
    @{ regex='localhost';                              type='metadata-ip-block' }
    @{ regex='0\.0\.0\.0';                             type='metadata-ip-block' }
    @{ regex='\bmetadata\b';                           type='metadata-ip-block' }
    @{ regex='dns\.lookup\s*\(';                       type='dns-resolution' }
    @{ regex='dns\.resolve';                           type='dns-resolution' }
    @{ regex="dns\.resolve(\d|4|6)";                   type='dns-resolution' }
    @{ regex='is-ip\b|isIP\b|net\.isIP';               type='dns-resolution' }
    @{ regex="hostname\s*(?:===?|==)\s*['`"']";        type='hostname-validation' }
    @{ regex='\.hostname\b';                           type='hostname-validation' }
    @{ regex='\.host\b';                               type='hostname-validation' }
)

# --------------------------------------------------------------------
# SCAN
# --------------------------------------------------------------------
$findings = @()
$linesScanned = 0

$sourcePatternsJoined = $sourcePatterns -join '|'

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

            # Skip comment-only lines (avoid matching 'fetch' in comments).
            if ($ln -match '^\s*[/#*]') { continue }

            foreach ($p in $sinkPatterns) {
                if ($ln -match $p.regex) {
                    # Find function scope: nearest function/arrow start before sink.
                    $funcStart = $li
                    for ($i = $li; $i -ge 0; $i--) {
                        if ($lines[$i] -match '(?:export\s+)?(?:async\s+)?function\s+' -or
                            $lines[$i] -match '(?:export\s+)?(?:const|let|var)\s+\w+\s*=\s*(?:async\s*)?\(' -or
                            $lines[$i] -match '^\s*\w+\s*\([^)]*\)\s*(?::\s*\w+\s*)?=>') {
                            $funcStart = $i
                            break
                        }
                    }

                    # Context window for source & validation (within function).
                    $ctxStart = [Math]::Max($funcStart, $li - 20)
                    $ctxEnd = [Math]::Min($lines.Count - 1, $li + 3)

                    # Build source window (includes comments).
                    $srcWindow = ($lines[$ctxStart..$ctxEnd] -join ' ')

                    # Build code-only window for validation (exclude comments).
                    $codeLines = @()
                    for ($i = $ctxStart; $i -le $ctxEnd; $i++) {
                        $l = $lines[$i]
                        if ($l -notmatch '^\s*[/#]' -and $l -notmatch '^\s*\*') {
                            $codeLines += $l
                        }
                    }
                    $codeWindow = $codeLines -join ' '

                    # Check for user-controlled source patterns.
                    $hasUserControl = $false
                    $userControlSource = ''
                    if ($srcWindow -match $sourcePatternsJoined) {
                        $hasUserControl = $true
                        $userControlSource = $matches[0]
                    }

                    # Fallback: variable name hint.
                    if (-not $hasUserControl) {
                        if ($ln -match $varHintPattern) {
                            $hasUserControl = $true
                            $userControlSource = 'variable-name-hint'
                        }
                    }

                    # Check validation heuristics in code-only window.
                    $validationTypes = @()
                    foreach ($vh in $validationHeuristics) {
                        if ($codeWindow -match $vh.regex) {
                            $validationTypes += $vh.type
                        }
                    }
                    $hasValidation = $validationTypes.Count -gt 0

                    # Deduplicate: if same file+line already recorded, skip.
                    $alreadySeen = $false
                    foreach ($f in $findings) {
                        if ($f.file -eq $rel -and $f.line -eq ($li + 1)) { $alreadySeen = $true; break }
                    }
                    if (-not $alreadySeen) {
                        $findings += @{
                            file = $rel
                            line = $li + 1
                            sinkType = $p.sink
                            hasUserControl = $hasUserControl
                            userControlSource = $userControlSource
                            hasValidation = $hasValidation
                            validationTypes = $validationTypes
                            code = $ln.Trim()
                        }
                    }
                    break
                }
            }
        }
    }
}

# --------------------------------------------------------------------
# REPORT
# --------------------------------------------------------------------
$userControlledCount = @($findings | Where-Object { $_.hasUserControl }).Count
$validatedCount = @($findings | Where-Object { $_.hasValidation }).Count
$unvalidatedUserControl = @($findings | Where-Object { $_.hasUserControl -and -not $_.hasValidation }).Count
$metadataRiskCount = @($findings | Where-Object {
    $_.hasUserControl -and -not ($_.validationTypes -contains 'metadata-ip-block')
}).Count

Write-Output "=== SSRF Scan Complete ==="
$fileSet = @($findings | ForEach-Object { $_.file } | Select-Object -Unique)
Write-Output "  Files with SSRF sinks: $($fileSet.Count)"
Write-Output "  Lines scanned: $linesScanned"
Write-Output "  Total SSRF sinks: $($findings.Count)"
Write-Output "  User-controlled URL sinks: $userControlledCount"
Write-Output "  With URL validation: $validatedCount"
Write-Output "  Unvalidated user-controlled: $unvalidatedUserControl"
Write-Output "  Metadata-service exploitable: $metadataRiskCount"

$result = @{
    findings = $findings
    counts = @{
        files = $fileSet.Count
        linesScanned = $linesScanned
        totalSinks = $findings.Count
        userControlled = $userControlledCount
        withValidation = $validatedCount
        unvalidatedUserControlled = $unvalidatedUserControl
        metadataServiceExploitable = $metadataRiskCount
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
