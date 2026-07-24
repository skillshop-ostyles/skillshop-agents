[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('ts', 'tsx', 'js', 'jsx', 'py', 'cs', 'go', 'rs', 'java', 'php', 'rb'),
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

$resources = New-Object System.Collections.Generic.List[object]
$counts = @{ total = 0; safe = 0; potentialLeak = 0; confirmedLeak = 0; intentionalEscape = 0 }

$acqPatterns = @(
    '(?i)(fs\.|File\.)(readFile|writeFile|createReadStream|createWriteStream|open)\s*\(',
    '(?i)(http|https)\.(get|request|createServer)\s*\(',
    '(?i)(mysql|pg|mongoose|prisma|redis|ioredis)\.(connect|createClient|createConnection|createPool)\s*\(',
    '(?i)(new\s+)?(WebSocket|Server|Socket|net\.createServer)\s*\(',
    '(?i)(setTimeout|setInterval|addListener|addEventListener|on\s*\()',
    '(?i)(open|fopen|fopen_s)\s*\(',
    '(?i)(malloc|calloc|realloc|new\s+\w+\[)',
    '(?i)(acquire|checkOut|getConnection|beginTransaction)'
)

$releasePatterns = '(?i)(close|dispose|end|unsubscribe|off\s*\()|(removeListener|removeEventListener|cleanup|free|release|defer\s|using\s|RAII|finally)'

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

        foreach ($pat in $acqPatterns) {
            if ($line -match $pat) {
                $resType = 'unknown'
                if ($line -match '(?i)(readFile|writeFile|open|fopen|stream)') { $resType = 'file-handle' }
                elseif ($line -match '(?i)(http|request|get|createServer)') { $resType = 'http-connection' }
                elseif ($line -match '(?i)(connect|createClient|pool|mongoose|prisma|redis|mysql|pg)') { $resType = 'db-connection' }
                elseif ($line -match '(?i)(socket|websocket|net\.)') { $resType = 'socket' }
                elseif ($line -match '(?i)(setTimeout|setInterval|addListener|addEventListener)') { $resType = 'subscription' }
                elseif ($line -match '(?i)(malloc|calloc|new\s+)') { $resType = 'memory' }
                elseif ($line -match '(?i)(acquire|checkOut|getConnection|transaction)') { $resType = 'pool-connection' }

                $counts.total++

                # Check for release in surrounding lines
                $startLookup = [Math]::Max(0, $i - 1)
                $endLookup = [Math]::Min($lines.Count - 1, $i + 5)
                $hasRelease = $false
                $releaseLine = $null
                for ($j = $startLookup; $j -le $endLookup; $j++) {
                    if ([string]$lines[$j] -match $releasePatterns) {
                        $hasRelease = $true
                        $releaseLine = $j + 1
                        break
                    }
                }

                $inFinally = $line -match '(?i)(finally|\.finally|defer\s|using\s|with\s+open|RAII)'
                $escapes = $line -match '(?i)(return|=>|callback|resolve|yield|push|add|store|save)'

                $classification = if ($hasRelease -and $inFinally) { 'safe' }
                elseif ($hasRelease) { 'potential-leak' }
                elseif ($escapes) { 'intentional-escape' }
                else { 'confirmed-leak' }

                switch ($classification) {
                    'safe' { $counts.safe++ }
                    'potential-leak' { $counts.potentialLeak++ }
                    'confirmed-leak' { $counts.confirmedLeak++ }
                    'intentional-escape' { $counts.intentionalEscape++ }
                }

                $resources.Add([ordered]@{
                        file              = $relPath
                        line              = $lineNum
                        resourceType      = $resType
                        classification    = $classification
                        hasExplicitRelease = $hasRelease
                        releaseLine       = $releaseLine
                        inFinallyBlock    = $inFinally
                        escapesScope      = $escapes
                        text              = $line.Trim()
                    })
                break
            }
        }
    }
}

$result = [ordered]@{
    resources = $resources.ToArray()
    counts    = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== RESOURCE-TRACE ==="
Write-Output "  Total resource acquisitions: $($counts.total)"
Write-Output "  Safe: $($counts.safe)"
Write-Output "  Potential leak: $($counts.potentialLeak)"
Write-Output "  Confirmed leak: $($counts.confirmedLeak)"
Write-Output "  Intentional escape: $($counts.intentionalEscape)"
