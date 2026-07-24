[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('ts', 'tsx', 'js', 'jsx', 'py', 'cs', 'go', 'rs', 'java', 'php', 'rb', 'kt'),
    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage', '__pycache__', '.next', '.nuxt')
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

function Find-NextBraceDepth($content, $startIndex) {
    $braceStart = $content.IndexOf('{', $startIndex)
    if ($braceStart -eq -1) { return $null }
    $depth = 0
    for ($i = $braceStart; $i -lt $content.Length; $i++) {
        $c = $content[$i]
        if ($c -eq '{') { $depth++ }
        elseif ($c -eq '}') {
            $depth--
            if ($depth -eq 0) {
                return @{
                    Body  = $content.Substring($braceStart, $i - $braceStart + 1)
                    Start = $braceStart
                    End   = $i
                }
            }
        }
    }
    return $null
}

function Get-SignalHandlerBody($content, $commaPos) {
    $trimmed = $content.Substring($commaPos + 1).TrimStart()
    if ($trimmed -eq '') { return $null }

    if ($trimmed -match '^(async\s+)?function') {
        $fnStart = $content.IndexOf('function', $commaPos)
        $parenStart = $content.IndexOf('(', $fnStart)
        if ($parenStart -eq -1) { return $null }
        $parenEnd = $content.IndexOf(')', $parenStart)
        if ($parenEnd -eq -1) { return $null }
        return Find-NextBraceDepth $content $parenEnd
    }

    if ($trimmed -match '^async\s') {
        $arrowStart = $content.IndexOf('=>', $commaPos)
        if ($arrowStart -eq -1) { return $null }
        $braceAfter = $content.IndexOf('{', $arrowStart)
        if ($braceAfter -eq -1) { return $null }
        return Find-NextBraceDepth $content $braceAfter
    }

    if ($trimmed -match '^\(' -or $trimmed -match '^{') {
        $arrowStart = $content.IndexOf('=>', $commaPos)
        if ($arrowStart -eq -1) {
            $braceStart = $content.IndexOf('{', $commaPos)
            if ($braceStart -eq -1) { return $null }
            return Find-NextBraceDepth $content $braceStart
        }
        $braceAfter = $content.IndexOf('{', $arrowStart)
        if ($braceAfter -eq -1) { return $null }
        return Find-NextBraceDepth $content $braceAfter
    }

    return $null
}

function IsOnCommentLine($content, $index) {
    $lineStart = $content.LastIndexOf("`n", $index)
    if ($lineStart -eq -1) { $lineStart = 0 } else { $lineStart++ }
    $line = $content.Substring($lineStart, $index - $lineStart)
    $trimmed = $line.TrimStart()
    if ($trimmed.StartsWith('//') -or $trimmed.StartsWith('#')) { return $true }
    return $false
}

function Strip-Comments($text) {
    $lines = $text -split "`n"
    $result = @()
    $inBlockComment = $false
    foreach ($line in $lines) {
        $out = ''
        $i = 0
        while ($i -lt $line.Length) {
            if ($inBlockComment) {
                $ci = $line.IndexOf('*/', $i)
                if ($ci -eq -1) { break }
                $inBlockComment = $false
                $i = $ci + 2
            } elseif ($line[$i] -eq '/' -and $i + 1 -lt $line.Length -and $line[$i+1] -eq '/') {
                break
            } elseif ($line[$i] -eq '/' -and $i + 1 -lt $line.Length -and $line[$i+1] -eq '*') {
                $inBlockComment = $true
                $i += 2
            } else {
                $out += $line[$i]
                $i++
            }
        }
        $result += $out
    }
    return ($result -join "`n")
}

function Get-SignalMechanism($value) {
    if ($value -match 'SIGTERM') { return 'SIGTERM' }
    if ($value -match 'SIGINT') { return 'SIGINT' }
    if ($value -match 'beforeExit') { return 'beforeExit' }
    if ($value -match "^exit$") { return 'exit' }
    if ($value -match 'onShutdown') { return 'lifecycle' }
    if ($value -match 'close') { return 'lifecycle' }
    return 'unknown'
}

function Classify-Path($handlerText, $criteria) {
    if ($handlerText -eq '') { return 'dangerous' }

    $immediateExit = $handlerText -match '(?i)process\.exit\s*\(' -and
                     -not ($handlerText -match '(?i)(\.close|drain|\.end|flush|disconnect|fsync)')

    if ($immediateExit) { return 'dangerous' }

    if ($criteria.hasGraceTimeout -and $criteria.drainsRequests -and
        $criteria.awaitsPending -and $criteria.flushesBuffers -and
        $criteria.releasesConnections -and $criteria.handlesShutdownErrors) {
        return 'safe'
    }

    if ($criteria.drainsRequests -and $criteria.hasGraceTimeout) {
        return 'mostly-safe'
    }

    if ($criteria.drainsRequests -or $criteria.hasGraceTimeout) {
        return 'risky'
    }

    return 'dangerous'
}

$shutdownPaths = New-Object System.Collections.Generic.List[object]
$counts = @{ total = 0; safe = 0; 'mostly-safe' = 0; risky = 0; dangerous = 0 }

$allFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
    Where-Object { -not (Test-ExcludedPath $_.FullName) }

foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    $content = $lines -join "`n"

    # Equivalent: process.on('SIGNAL',   or   process.on("SIGNAL",
    # We match the full construct to detect signal handlers.
    $sigCallPattern = 'process\.on\s*\(\s*[''"](SIGTERM|SIGINT|beforeExit|exit)[''""]\s*,'

    $sigCallMatches = [regex]::Matches($content, $sigCallPattern, 'IgnoreCase')
    foreach ($m in $sigCallMatches) {
        if (IsOnCommentLine $content $m.Index) { continue }

        $signalName = $m.Groups[1].Value
        $mechanism = Get-SignalMechanism $signalName

        # Find the comma that ends the signal name argument
        $commaPos = $content.IndexOf(',', $m.Index)
        if ($commaPos -eq -1) { continue }
        # Advance past any whitespace and optional newline to the handler
        $handlerBlock = Get-SignalHandlerBody $content $commaPos
        $handlerText = if ($handlerBlock) { Strip-Comments $handlerBlock.Body } else { '' }

        $criteria = @{
            hasGraceTimeout       = $handlerText -match '(?i)(timeout|gracePeriod|graceTimeout|grace_period|grace\s*period|setTimeout.*\d{4,}|await\s+sleep|await\s+delay|await\s+wait)'
            drainsRequests        = $handlerText -match '(?i)(\.close\s*\(|\.destroy\s*\(|drain\s*\(|noMoreJobs|pause\s*\(|\.end\s*\()'
            awaitsPending         = $handlerText -match '(?i)\bawait\b'
            flushesBuffers        = $handlerText -match '(?i)(flush|fsync|stream\.end|\.end\s*\(|writeFile|writeSync)'
            releasesConnections   = $handlerText -match '(?i)(disconnect|\.end\s*\(|\.release\s*\(|\.destroy\s*\(|pool\.end|mongoose\.disconnect|client\.close)'
            handlesShutdownErrors = $handlerText -match "(?i)(\.catch\s*\(|try\s*\{|catch\s*\(|error\s*=>|err\s*=>|onerror|onError|['']error[''])"
        }

        $classification = Classify-Path $handlerText $criteria

        $counts.total++
        $counts.$classification++

        $shutdownPaths.Add([ordered]@{
                processName           = $relPath
                mechanism             = $mechanism
                hasGraceTimeout       = [bool]$criteria.hasGraceTimeout
                drainsRequests        = [bool]$criteria.drainsRequests
                awaitsPending         = [bool]$criteria.awaitsPending
                flushesBuffers        = [bool]$criteria.flushesBuffers
                releasesConnections   = [bool]$criteria.releasesConnections
                handlesShutdownErrors = [bool]$criteria.handlesShutdownErrors
                classification        = $classification
            })
    }

    # Additional checks for lifecycle and framework hooks
    $lifecyclePatterns = @(
        '(?i)onShutdown\s*\(',
        '(?i)app\.on\s*\(\s*[''""]close[''""]',
        '(?i)beforeExit\s*\(',
        '(?i)__shutdown\s*=\s*',
        '(?i)shutdown\s*:\s*function',
        '(?i)shutdown\s*\(\s*\)'
    )
    foreach ($lcPat in $lifecyclePatterns) {
        $lcMatches = [regex]::Matches($content, $lcPat)
        foreach ($m in $lcMatches) {
            if (IsOnCommentLine $content $m.Index) { continue }

            # Check if this file already has a matching signal-path entry
            $alreadyCounted = $shutdownPaths | Where-Object {
                $_.processName -eq $relPath -and $_.mechanism -eq 'lifecycle'
            }
            if ($alreadyCounted) { continue }

            # Try to extract the lifecycle handler body
            $handlerBlock = Get-SignalHandlerBody $content $m.Index
            $handlerText = if ($handlerBlock) { Strip-Comments $handlerBlock.Body } else { '' }

            $criteria = @{
                hasGraceTimeout       = $handlerText -match '(?i)(timeout|gracePeriod|graceTimeout|grace_period)'
                drainsRequests        = $handlerText -match '(?i)(\.close|\.destroy|drain|\.end)'
                awaitsPending         = $handlerText -match '(?i)\bawait\b'
                flushesBuffers        = $handlerText -match '(?i)(flush|fsync|stream\.end|writeFile|writeSync)'
                releasesConnections   = $handlerText -match '(?i)(disconnect|\.end|\.release|\.destroy|pool\.end|mongoose\.disconnect)'
                handlesShutdownErrors = $handlerText -match '(?i)(catch|error|err)'
            }

            $classification = Classify-Path $handlerText $criteria

            $counts.total++
            $counts.$classification++

            $shutdownPaths.Add([ordered]@{
                    processName           = $relPath
                    mechanism             = 'lifecycle'
                    hasGraceTimeout       = [bool]$criteria.hasGraceTimeout
                    drainsRequests        = [bool]$criteria.drainsRequests
                    awaitsPending         = [bool]$criteria.awaitsPending
                    flushesBuffers        = [bool]$criteria.flushesBuffers
                    releasesConnections   = [bool]$criteria.releasesConnections
                    handlesShutdownErrors = [bool]$criteria.handlesShutdownErrors
                    classification        = $classification
                })
        }
    }

    # Detect processes that declare servers/workers/connections but have NO shutdown handler
    $hasAnyShutdownHandler = $shutdownPaths | Where-Object { $_.processName -eq $relPath }
    if (-not $hasAnyShutdownHandler) {
        $serverPatterns = @(
            '(?i)(app|server)\.listen\s*\(',
            '(?i)createServer\s*\(',
            '(?i)Queue\s*\(',
            '(?i)new\s+Pool\s*\(',
            '(?i)createWriteStream'
        )
        $hasServer = $false
        foreach ($sPat in $serverPatterns) {
            if ($content -match $sPat) {
                $hasServer = $true
                break
            }
        }
        if ($hasServer) {
            $criteria = @{
                hasGraceTimeout       = $content -match '(?i)(grace|timeout|gracePeriod|graceTimeout)'
                drainsRequests        = $false
                awaitsPending         = $false
                flushesBuffers        = $false
                releasesConnections   = $false
                handlesShutdownErrors = $false
            }

            $counts.total++
            $counts.dangerous++

            $shutdownPaths.Add([ordered]@{
                    processName           = $relPath
                    mechanism             = 'none'
                    hasGraceTimeout       = [bool]$criteria.hasGraceTimeout
                    drainsRequests        = $false
                    awaitsPending         = $false
                    flushesBuffers        = $false
                    releasesConnections   = $false
                    handlesShutdownErrors = $false
                    classification        = 'dangerous'
                })
        }
    }
}

$result = [ordered]@{
    shutdownPaths = $shutdownPaths.ToArray()
    counts        = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)
Write-Output "`n=== SHUTDOWN-DETAIL-SCAN ==="
Write-Output "  Total shutdown paths: $($counts.total) (safe=$($counts.safe) mostly-safe=$($counts['mostly-safe']) risky=$($counts.risky) dangerous=$($counts.dangerous))"
