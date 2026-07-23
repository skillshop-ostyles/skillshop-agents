[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.cs,*.go,*.java,*.rb,*.php,*.rs",
    [string]$Exclude = ""
)

$ErrorActionPreference = 'Stop'
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

$integrations = @()

# HTTP client patterns
$httpPatterns = @(
    'fetch\([\x27\x22]?(https?://[\w\.\-]+)',
    'axios\.\w+\([\x27\x22]?(https?://[\w\.\-]+)',
    'got\([\x27\x22]?(https?://[\w\.\-]+)',
    'request\([\x27\x22]?(https?://[\w\.\-]+)',
    'requests\.\w+\([\x27\x22]?(https?://[\w\.\-]+)',
    'Invoke-RestMethod.*-Uri\s+[\x27\x22]?(https?://[\w\.\-]+)',
    'HttpClient\.\w+Async\([\x27\x22]?(https?://[\w\.\-]+)'
)

# DB connection patterns
$dbPatterns = @(
    '(postgres|mysql|mongodb|sqlserver|redis)://[\w\.\-]+',
    'host=\w+.*port=\d+',
    'server=\w+.*database=\w+'
)

# Queue patterns
$queuePatterns = @(
    'Kafka|kafka|KafkaProducer|@KafkaListener',
    'RabbitMQ|rabbitmq|amqp://',
    'SQS|sqs|AmazonSQS',
    'ChannelFactory|IMessageProducer'
)

# Storage patterns
$storagePatterns = @(
    'S3Client|s3\.\w+|@Minio|minio',
    'BlobClient|BlobStorage',
    'File\.WriteAllText|WriteAllLines'
)

# Retry/fallback patterns
$retryPatterns = @(
    'retry|Retry|retryPolicy|RetryPolicy|retryOptions|withRetry'
)
$fallbackPatterns = @(
    'fallback|Fallback|catch\s*\(.*\)\s*\{[^}]*return\s|\.catch\(.*=>\s*\{[^}]*return'
)
$circuitBreakerPatterns = @(
    'circuitBreaker|CircuitBreaker|@CircuitBreaker|breakCircuit'
)

# Criticality heuristics
function Get-Criticality($target, $lines) {
    $text = ($lines -join ' ') -replace '[\x27\x22]', ''
    if ($text -match 'stripe|payment|charge|checkout|invoice|billing') { return "critical" }
    if ($text -match 'sendgrid|email|mail|notification|sms|twilio') { return "high" }
    if ($text -match 'redis|cache|session|log|analytics|track') { return "medium" }
    return "low"
}

$count = 0

foreach ($ext in ($Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    $items = Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue
    foreach ($i in $items) {
        $fn = $i.FullName
        $accept = $true
        if ($fn -match '[\\/]node_modules[\\/]|[\\/]\.git[\\/]|[\\/]venv[\\/]|[\\/]__pycache__[\\/]|[\\/]dist[\\/]|[\\/]build[\\/]') { $accept = $false }
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

        $foundTypes = @{}
        foreach ($line in $lines) {
            $t = $line.Trim()
            if ($t -match '^\s*(//|#|import|require)') { continue }

            # Check HTTP calls
            foreach ($pat in $httpPatterns) {
                if ($t -match $pat) {
                    $target = $matches[1]
                    $foundTypes["http"] = @{
                        type = "http"; target = $target; protocol = "HTTPS"
                        hasRetry = ($t -match ($retryPatterns -join '|'))
                        hasFallback = ($t -match ($fallbackPatterns -join '|'))
                        hasCircuitBreaker = ($t -match ($circuitBreakerPatterns -join '|'))
                        authType = if ($t -match 'Bearer|Authorization|apiKey|token:') { "key" } else { "none" }
                    }
                }
            }
            # Check DB connections
            foreach ($pat in $dbPatterns) {
                if ($t -match $pat) {
                    $target = $matches[0]
                    $foundTypes["db"] = @{
                        type = "db"; target = $target -replace '[\x27\x22]', ''; protocol = if ($target -match 'redis') { "Redis" } else { "SQL/NoSQL" }
                        hasRetry = ($t -match ($retryPatterns -join '|'))
                        hasFallback = ($t -match ($fallbackPatterns -join '|'))
                        hasCircuitBreaker = $false
                        authType = if ($target -match '@') { "embedded" } else { "env" }
                    }
                }
            }
            # Check queues
            foreach ($pat in $queuePatterns) {
                if ($t -match $pat) {
                    $target = $matches[0]
                    $foundTypes["queue"] = @{ type = "queue"; target = $target; protocol = "PubSub"; hasRetry = $false; hasFallback = $false; hasCircuitBreaker = $false; authType = "env" }
                }
            }
            # Check storage
            foreach ($pat in $storagePatterns) {
                if ($t -match $pat) {
                    $target = $matches[0]
                    $foundTypes["storage"] = @{ type = "storage"; target = $target; protocol = "HTTP/REST"; hasRetry = $false; hasFallback = $false; hasCircuitBreaker = $false; authType = "key" }
                }
            }
        }

        foreach ($key in $foundTypes.Keys) {
            $integration = $foundTypes[$key]
            $integration.file = $rel
            $criticality = Get-Criticality $integration.target $lines
            $integration.criticality = $criticality
            $integrations += $integration
        }
    }
}

Write-Output "=== Integration Landscape Complete ==="
Write-Output "  Files scanned: $count"
Write-Output "  Integrations found: $($integrations.Count)"
foreach ($c in @("critical", "high", "medium", "low")) {
    $cCount = @($integrations | Where-Object { $_.criticality -eq $c }).Count
    Write-Output "    $c : $cCount"
}

$result = @{
    scannedFiles = $count
    integrations = $integrations
    riskSummary = @{
        critical = @($integrations | Where-Object { $_.criticality -eq "critical" }).Count
        high = @($integrations | Where-Object { $_.criticality -eq "high" }).Count
        medium = @($integrations | Where-Object { $_.criticality -eq "medium" }).Count
        low = @($integrations | Where-Object { $_.criticality -eq "low" }).Count
    }
}
Write-Output ($result | ConvertTo-Json -Depth 5)
exit 0
