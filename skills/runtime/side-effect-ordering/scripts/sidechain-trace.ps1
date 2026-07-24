[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('ts', 'tsx', 'js', 'jsx', 'py', 'cs', 'go', 'rs', 'java', 'php', 'rb', 'kt'),
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

function Test-ExcludedPath($fullPath) {
    $rel = $fullPath.Substring($root.Length).TrimStart('\', '/')
    foreach ($part in ($rel -split '[\\/]')) {
        if ($excludeSet -contains $part.ToLower()) { return $true }
    }
    return $false
}

$handlers = New-Object System.Collections.Generic.List[object]
$counts = @{ total = 0; dangerous = 0; inverted = 0; risky = 0; safe = 0 }

# Handler definition patterns
$handlerPatterns = @(
    '(?i)(app|router|route)\.(get|post|put|delete|patch|head|options)\s*\(',
    '(?i)@(app|api)\.route\s*\(',
    '(?i)queue\.process\s*\(',
    '(?i)consumer\.handle\s*\(',
    '(?i)handler\.handle\s*\(',
    '(?i)on\(\s*''(?:message|event)''',
    '(?i)job\.process\s*\(',
    '(?i)addEventListener\s*\('
)

# Side-effect operation patterns
$opPatterns = @(
    @{ name = 'db-write'; pattern = '(?i)\b(INSERT|UPDATE|DELETE)\b'; targetCaptureIndex = 0 },
    @{ name = 'db-write'; pattern = '(?i)\.(save|create|update|delete)\s*\('; targetCaptureIndex = 1 },
    @{ name = 'api-call'; pattern = '(?i)axios\.\w+'; targetCaptureIndex = 0 },
    @{ name = 'api-call'; pattern = 'fetch\s*\('; targetCaptureIndex = 0 },
    @{ name = 'api-call'; pattern = '(?i)http\.request'; targetCaptureIndex = 0 },
    @{ name = 'api-call'; pattern = 'got\s*\('; targetCaptureIndex = 0 },
    @{ name = 'api-call'; pattern = 'request\s*\('; targetCaptureIndex = 0 },
    @{ name = 'event'; pattern = '(?i)\.(emit|publish|send|produce)\s*\('; targetCaptureIndex = 1 },
    @{ name = 'cache-write'; pattern = '(?i)\.(set|setex|mset)\s*\('; targetCaptureIndex = 1 },
    @{ name = 'file-write'; pattern = '(?i)writeFile(?:Sync)?'; targetCaptureIndex = 0 },
    @{ name = 'file-write'; pattern = '(?i)createWriteStream'; targetCaptureIndex = 0 },
    @{ name = 'payment'; pattern = '(?i)\b(charge|capture|refund|payment|invoice)\b'; targetCaptureIndex = 0 }
)

$allFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
    Where-Object { -not (Test-ExcludedPath $_.FullName) }

foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    $content = $lines -join "`n"

    # Find handler definitions
    foreach ($hp in $handlerPatterns) {
        $hMatches = [regex]::Matches($content, $hp)
        foreach ($hm in $hMatches) {
            $handlerStartLine = $hm.Index
            $handlerLineNum = 1
            for ($i = 0; $i -lt $lines.Count; $i++) {
                $absPos = ($lines[0..$i] -join "`n").Length
                if ($absPos -gt $handlerStartLine) { $handlerLineNum = $i + 1; break }
            }

            # Extract handler name
            $handlerName = $hm.Value.Trim()
            $handlerNameMatch = [regex]::Match($hm.Value, '(?:get|post|put|delete|patch|on|handle|process|addEventListener)\s*\(([^)]*)\)')
            if ($handlerNameMatch.Success -and $handlerNameMatch.Groups[1].Value) {
                $handlerName = $handlerNameMatch.Groups[1].Value.Trim().Trim('''"')
            }

            # Find function body boundaries (brace matching)
            $bodyStart = $hm.Index + $hm.Length
            if ($bodyStart -ge $content.Length) { continue }

            # Find opening brace after handler definition
            $bracePos = $content.IndexOf('{', $bodyStart)
            if ($bracePos -lt 0) { continue }

            # Simple brace matching
            $depth = 1
            $bodyEnd = $bracePos + 1
            while ($depth -gt 0 -and $bodyEnd -lt $content.Length) {
                $ch = $content[$bodyEnd]
                if ($ch -eq '{') { $depth++ }
                elseif ($ch -eq '}') { $depth-- }
                $bodyEnd++
            }
            if ($depth -ne 0) { continue }

            $body = $content.Substring($bracePos + 1, ($bodyEnd - $bracePos - 2))

            # Extract operation chain from body in execution order
            $operationChain = New-Object System.Collections.Generic.List[object]
            $prevOps = @()

            $bodyLines = $body -split "`n"
            foreach ($bl in $bodyLines) {
                $trimmed = $bl.Trim()
                if (-not $trimmed) { continue }

                foreach ($opDef in $opPatterns) {
                    $opMatches = [regex]::Matches($trimmed, $opDef.pattern)
                    foreach ($om in $opMatches) {
                        $target = ''
                        if ($opDef.targetCaptureIndex -gt 0 -and $om.Groups.Count -gt $opDef.targetCaptureIndex) {
                            $target = $om.Groups[$opDef.targetCaptureIndex].Value
                        }

                        # Determine isReversible
                        $isReversible = $true
                        if ($opDef.name -eq 'payment') { $isReversible = $false }
                        if ($opDef.name -eq 'db-write') { $isReversible = $true }

                        # Data dependencies: check if this line uses variables from prior ops
                        $dataDeps = New-Object System.Collections.Generic.List[object]
                        $usedVars = [regex]::Matches($trimmed, '\b(\w+)\b') | ForEach-Object { $_.Value }
                        foreach ($pv in $prevOps) {
                            if ($usedVars -contains $pv) { $dataDeps.Add($pv) }
                        }

                        # Track variable assignments for dependency tracking
                        $varAssign = [regex]::Match($trimmed, '(?:const|let|var)\s+(\w+)\s*=')
                        if ($varAssign.Success) { $prevOps += $varAssign.Groups[1].Value }

                        $operationChain.Add([ordered]@{
                            type            = $opDef.name
                            target          = $target
                            isReversible    = $isReversible
                            dataDependencies = @($dataDeps.ToArray())
                            codeSnippet     = $trimmed.Substring(0, [Math]::Min(120, $trimmed.Length))
                        })

                        break
                    }
                }
            }

            # Classification
            $classification = 'safe'
            $opsArr = $operationChain.ToArray()
            $hasIrreversible = $false
            $hasReversibleAfterIrreversible = $false
            $hasCacheBeforeDb = $false
            $hasNonTransactionalDep = $false

            for ($oi = 0; $oi -lt $opsArr.Length; $oi++) {
                $op = $opsArr[$oi]

                if (-not $op.isReversible) { $hasIrreversible = $true }
                if ($hasIrreversible -and $op.isReversible) { $hasReversibleAfterIrreversible = $true }

                if ($op.type -eq 'cache-write') {
                    for ($oj = $oi + 1; $oj -lt $opsArr.Length; $oj++) {
                        if ($opsArr[$oj].type -eq 'db-write') { $hasCacheBeforeDb = $true; break }
                    }
                }

                if ($op.dataDependencies.Count -gt 0 -and $oi -gt 0) {
                    $priorOp = $opsArr[$oi - 1]
                    if (-not $priorOp.isReversible -or $priorOp.type -eq 'api-call') {
                        $hasNonTransactionalDep = $true
                    }
                }
            }

            if ($hasReversibleAfterIrreversible) { $classification = 'dangerous' }
            elseif ($hasCacheBeforeDb) { $classification = 'inverted' }
            elseif ($hasNonTransactionalDep) { $classification = 'risky' }
            else { $classification = 'safe' }

            $counts.total++
            $counts.$classification++

            $handlers.Add([ordered]@{
                file                   = $relPath
                handlerName            = $handlerName
                lineNumber             = $handlerLineNum
                handlerClassification  = $classification
                operationChain         = @($operationChain.ToArray())
            })
        }
    }
}

$result = [ordered]@{
    handlers = @($handlers.ToArray())
    counts   = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== SIDECHAIN-TRACE ==="
Write-Output "  Handlers scanned: $($counts.total)"
Write-Output "  Safe: $($counts.safe)"
Write-Output "  Dangerous: $($counts.dangerous)"
Write-Output "  Inverted: $($counts.inverted)"
Write-Output "  Risky: $($counts.risky)"