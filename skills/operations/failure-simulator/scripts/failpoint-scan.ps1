[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir
)

$ErrorActionPreference = 'Stop'
$pdir = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $pdir) { Write-Error "Path not found: $ProjectDir"; exit 1 }

$failpoints = New-Object System.Collections.ArrayList
$scannedFiles = 0
$exts = @('*.ps1','*.py','*.js','*.ts','*.cs','*.go','*.java','*.rb','*.php')

foreach ($ext in $exts) {
    $files = Get-ChildItem -LiteralPath $pdir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        $fp = $f.FullName
        if ($fp -match 'node_modules|\.git|venv|bin|obj|__pycache__') { continue }
        $scannedFiles++
        $content = Get-Content -LiteralPath $fp -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $lines = $content -split "`r`n|`n"
        $rel = $fp.Substring($pdir.Path.Length).TrimStart('\')

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i].Trim()
            if ($line -eq '' -or $line -match '^(#|//|--|\*)') { continue }

            $type = $null
            if ($line -match 'fetch\s*\(|axios\.|\bHttpClient\b|http\.Get|requests\.|Invoke-RestMethod|got\s*\(') { $type = 'http' }
            elseif ($line -match '\.query\s*\(|\.execute\s*\(|\.find\s*\(|\.findOne\s*\(|\.save\s*\(|\bSELECT\b|\bINSERT\b|\bUPDATE\b|connection\.|createPool\s*\(|prisma\.|dbContext\.') { $type = 'db' }
            elseif ($line -match 'readFile|writeFile|fopen|File\.Read|File\.Write|Get-Content\s|Set-Content\s|readFileSync|writeFileSync|existsSync|mkdirSync') { $type = 'fs' }
            elseif ($line -match 'publish\s*\(|subscribe\s*\(|sendMessage\s*\(|consume\s*\(|amqp\.|kafka\.|rabbit\.|sqs\.|bus\.') { $type = 'queue' }
            elseif ($line -match 'redis\.|memcache|cache\.get\s*\(|cache\.set\s*\(|ioredis|createClient\s*\(') { $type = 'cache' }
            if (-not $type) { continue }

            $start = [Math]::Max(0, $i - 6)
            $end = [Math]::Min($lines.Count, $i + 7)
            $ctx = $lines[$start..($end-1)]

            $surr = $ctx -join "`n"
            $hasTryCatch = $surr -match '\btry\b|\bcatch\b|\bfinally\b'
            $hasRetry = $surr -match 'retry|backoff|circuit'
            $hasTimeout = $surr -match 'timeout|abort|deadline|ttl'

            $null = $failpoints.Add(@{
                type = $type
                file = $rel
                line = $i + 1
                text = $line.Substring(0, [Math]::Min(120, $line.Length))
                context = $ctx
                hasTryCatch = $hasTryCatch
                hasRetrySignal = $hasRetry
                hasTimeoutSignal = $hasTimeout
            })
        }
    }
}

$ct = @{}
foreach ($fp in $failpoints) { $ct[$fp.type] = ($ct[$fp.type] + 1) }

$result = @{ failpoints = @($failpoints); countsByType = $ct; scannedFiles = $scannedFiles }

Write-Output "=== Failure Point Scan Complete ==="
Write-Output "  Files scanned: $scannedFiles"
Write-Output "  Total failpoints: $($failpoints.Count)"
foreach ($t in $ct.Keys | Sort-Object) { Write-Output "  $t`: $($ct[$t])" }

Write-Output ($result | ConvertTo-Json -Depth 10)
exit 0
