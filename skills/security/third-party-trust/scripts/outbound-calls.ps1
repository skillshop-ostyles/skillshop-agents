[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.cs,*.go,*.java,*.rb,*.php",
    [string]$Exclude = ""
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

# Outbound HTTP/RPC patterns. URL may be string-literal OR variable.
$callPatterns = @(
    # fetch with literal URL
    @{ regex='\bfetch\s*\(\s*["\x27]"?(?<url>[^"\x27,)]+)["\x27]?\s*[,)]'; lang='js'; lib='fetch' },
    # fetch with variable URL
    @{ regex='\bfetch\s*\(\s*(?<url>[A-Za-z_]\w*)(\s*[,)]|\s*\.\s*then)'; lang='js'; lib='fetch' },
    # axios with literal URL
    @{ regex='\baxios\s*\.\s*(?:get|post|put|patch|delete|request)\s*\(\s*["\x27]"?(?<url>[^"\x27,]+)["\x27]?\s*[,)]'; lang='js'; lib='axios' },
    # axios(config) - URL inside object literal
    @{ regex='\baxios\s*\(\s*\{[^}]*["\x27]url["\x27]\s*:\s*["\x27]"?(?<url>[^"\x27,]+)["\x27]?'; lang='js'; lib='axios' },
    # got/request
    @{ regex='\bgot\s*\(\s*["\x27]"?(?<url>[^"\x27,]+)["\x27]?\s*[,)]'; lang='js'; lib='got' },
    @{ regex='\brequest\s*\(\s*["\x27]"?(?<url>[^"\x27,]+)["\x27]?\s*[,)]'; lang='js'; lib='request' },
    # PowerShell
    @{ regex='\bInvoke-RestMethod\s+-Uri\s+["\x27]"?(?<url>[^"\x27]+)["\x27]'; lang='ps'; lib='Invoke-RestMethod' },
    @{ regex='\bInvoke-WebRequest\s+-Uri\s+["\x27]"?(?<url>[^"\x27]+)["\x27]'; lang='ps'; lib='Invoke-WebRequest' },
    # curl
    @{ regex='\bcurl\s+(?:-[A-Z]\s+\S+\s+)*["\x27]"?(?<url>[^"\x27 \t][^"\x27]*[^"\x27 \t])["\x27]?'; lang='sh'; lib='curl' },
    # Python requests
    @{ regex='\brequests\s*\.\s*(?:get|post|put|patch|delete|request)\s*\(\s*["\x27]"?(?<url>[^"\x27,]+)["\x27]?\s*[,)]'; lang='py'; lib='requests' }
)

# Next-line or attribute: any auth header / API key env var nearby.
$authInlinePatterns = @(
    "['\x22]Authorization['\x22]\s*[:=]\s*",
    "api[_-]?key\s*[:=]\s*",
    "['\x22]apikey['\x22]\s*[:=]\s*",
    "['\x22]access[_-]?token['\x22]\s*[:=]\s*",
    "['\x22]bearer\s+"
)

$outboundCalls = @()
$scannedFiles = 0

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
        $scannedFiles++
        $content = Get-Content -LiteralPath $fn -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $rel = $fn.Substring($ProjectDir.Length).TrimStart('\')
        $lines = $content -split "`n"

        for ($li = 0; $li -lt $lines.Count; $li++) {
            $ln = $lines[$li]
            foreach ($p in $callPatterns) {
                if ($ln -match $p.regex) {
                    $urlVal = if ($matches.ContainsKey('url')) { $matches['url'] } else { '' }
                    if (-not $urlVal) { continue }

                    # Detect URL-template vs literal: contains < or ${ or req.
                    $isTemplate = $urlVal -match '<.+>' -or $urlVal -match '\$\{' -or $urlVal -match 'req\.' -or $urlVal -match 'req_' -or $urlVal -match 'args\.'

                    # Inspect neighborhood (-3..+3) for auth references.
                    $ctxStart = [Math]::Max(0, $li - 3)
                    $ctxEnd = [Math]::Min($lines.Count - 1, $li + 3)
                    $window = ($lines[$ctxStart..$ctxEnd] -join ' ')
                    $authHint = $false
                    foreach ($ap in $authInlinePatterns) {
                        if ($window -match $ap) { $authHint = $true; break }
                    }

                    # Same line range inspect for retry/error handling.
                    $retryCount = ([regex]::Matches($window, '\.retry\(|retries\s*[:=]|backoff|\.repeat\s*\(|catch\s*\([^)]*\)\s*\{\s*throw')).Count

                    # Webhook-handler detection (function has app.post/listen with raw body).
                    $isWebhookHandler = $false
                    if ($p.lib -eq 'express' -or $p.lib -eq 'fetch') {
                        if ($window -match 'express\(\)|express()|app\.use\(.bodyParser|app\.use\(express\.json') { $isWebhookHandler = $true }
                    }

                    $outboundCalls += @{
                        file = $rel
                        line = $li + 1
                        lib = $p.lib
                        url = $urlVal
                        isTemplateUrl = $isTemplate
                        authHint = $authHint
                        retrySignals = $retryCount
                        webhookHandler = $isWebhookHandler
                        lineContent = $ln
                    }
                    break  # only first matching pattern per line
                }
            }
        }
    }
}

# Categorize URL into known-trusted domain bucket (LLM will get more specific).
$trustedDomains = @{
    'stripe.com' = 'payment'; 'amazonaws.com' = 'aws'; 'amazon.com' = 'aws'
    'googleapis.com' = 'gcp'; 'azure.com' = 'azure'; 'github.com' = 'github'
    'supabase.co' = 'supabase'; 'firebaseio.com' = 'firebase'; 'mongodb.com' = 'mongo'
    'cloudfront.net' = 'aws'; 's3.amazonaws.com' = 'aws'
}
foreach ($c in $outboundCalls) {
    $kind = 'unknown'
    foreach ($d in $trustedDomains.Keys) {
        if ($c.url -match [regex]::Escape($d)) { $kind = $trustedDomains[$d]; break }
    }
    $c.trustKind = $kind
}

Write-Output "=== Third-Party-Trust Scan Complete ==="
Write-Output "  Files scanned: $scannedFiles"
Write-Output "  Outbound calls: $($outboundCalls.Count)"
Write-Output "  With template URL (user-controlled risk): $(@($outboundCalls | Where-Object { $_.isTemplateUrl }).Count)"
Write-Output "  Webhook handlers detected: $(@($outboundCalls | Where-Object { $_.webhookHandler }).Count)"
Write-Output "  With explicit auth hint: $(@($outboundCalls | Where-Object { $_.authHint }).Count)"

$result = @{
    calls = $outboundCalls
    counts = @{
        scannedFiles = $scannedFiles
        totalCalls = $outboundCalls.Count
        templateUrls = (@($outboundCalls | Where-Object { $_.isTemplateUrl }).Count)
        webhookHandlers = (@($outboundCalls | Where-Object { $_.webhookHandler }).Count)
        withAuthHint = (@($outboundCalls | Where-Object { $_.authHint }).Count)
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
