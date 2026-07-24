[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.rb,*.java,*.go,*.php"
)

$ErrorActionPreference = 'Stop'
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

$loopPatterns = @(
    'for\s*\(', 'for\s+of\s', 'for\s+in\s', '\.forEach\s*\(', '\.map\s*\(',
    '\.filter\s*\(', '\.reduce\s*\(', 'while\s*\(', 'do\s*\{'
)

$queryCallPatterns = @(
    '\.find\s*\(', '\.findMany\s*\(', '\.findAll\s*\(', '\.findOne\s*\(',
    '\.fetch\s*\(', '\.query\s*\(', '\.select\s*\(', '\.get\s*\(',
    '\.create\s*\(', '\.update\s*\(', '\.insert\s*\(', '\.save\s*\(',
    '\.raw\s*\(', '\.execute\s*\('
)

$batchHintPatterns = @(
    'include\s*:', 'relations\s*:', 'whereIn\s*\(', 'where_id_in',
    '\bIN\s*\(', 'join\s', 'eagerLoad', 'eager', 'select\s*\(', 'populate\s*\('
)

Remove-Variable -Name candidates -Scope Global -ErrorAction SilentlyContinue
$script:candidates = @()
$scannedFiles = 0

$extList = $Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

foreach ($ext in $extList) {
    Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch 'node_modules|\.git|venv|bin|obj|__pycache__|dist|build'
    } | ForEach-Object {
        $fp = $_.FullName
        $scannedFiles++
        $content = Get-Content -LiteralPath $fp -Raw -ErrorAction SilentlyContinue
        if (-not $content) { return }
        $rel = $fp.Substring($ProjectDir.Length).TrimStart('\')
        $lines = $content -split "`r`n|`n"

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $lineNum = $i + 1

            foreach ($loopPat in $loopPatterns) {
                if ($line -match $loopPat) {
                    $loopType = 'unknown'
                    if ($line -match 'for\s*\(') { $loopType = 'for' }
                    elseif ($line -match 'for\s+of') { $loopType = 'for-of' }
                    elseif ($line -match 'for\s+in') { $loopType = 'for-in' }
                    elseif ($line -match '\.forEach') { $loopType = 'forEach' }
                    elseif ($line -match '\.map') { $loopType = 'map' }
                    elseif ($line -match 'while') { $loopType = 'while' }
                    elseif ($line -match 'do\s*\{') { $loopType = 'do-while' }

                    $loopSource = ''
                    if ($line -match 'for\s*\(\s*(?:var|let|const)\s+(\w+)\s+of\s+(\w+)') {
                        $loopSource = $matches[2]
                    } elseif ($line -match 'for\s*\(\s*(?:var|let|const)\s+(\w+)\s+in\s+(\w+)') {
                        $loopSource = $matches[2]
                    } elseif ($line -match 'for\s*\([^)]*\)') {
                        $loopSource = 'iterable'
                    }

                    $loopBody = @()
                    $braceDepth = 0
                    $started = $false
                    $loopEndLine = $i
                    for ($j = $i; $j -lt $lines.Count; $j++) {
                        $loopBody += $lines[$j]
                        $braceDepth += ($lines[$j] -split '\{').Count - 1
                        $braceDepth -= ($lines[$j] -split '\}').Count - 1
                        if ($lines[$j] -match '\{') { $started = $true }
                        if ($started -and $braceDepth -le 0 -and $j -gt $i) {
                            $loopEndLine = $j
                            break
                        }
                        if ($j -gt $i + 30) {
                            $loopEndLine = $j
                            break
                        }
                    }

                    # Also check lines after the loop for batch queries (e.g., .map collecting IDs then batch query)
                    for ($j = $loopEndLine + 1; $j -le [Math]::Min($loopEndLine + 3, $lines.Count - 1); $j++) {
                        $loopBody += $lines[$j]
                    }

                    foreach ($queryPat in $queryCallPatterns) {
                        foreach ($bodyLine in $loopBody) {
                            if ($bodyLine -match $queryPat) {
                                $hasBatchHint = $false
                                foreach ($batchPat in $batchHintPatterns) {
                                    if ($loopBody -match $batchPat) {
                                        $hasBatchHint = $true
                                        break
                                    }
                                }

                                if (-not $hasBatchHint -and $loopType -eq 'map' -and $line -notmatch '\{') {
                                    $hasBatchHint = $true
                                }

                                $queryCall = $bodyLine.Trim()
                                if ($queryCall.Length -gt 200) {
                                    $queryCall = $queryCall.Substring(0, 200) + '...'
                                }

                                $script:candidates += @{
                                    file = $rel
                                    line = $lineNum
                                    loopType = $loopType
                                    loopSource = $loopSource
                                    queryCall = $queryCall
                                    hasBatchHint = $hasBatchHint
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

$realNPlusOne = 0; $batchOrEager = 0
foreach ($c in $script:candidates) {
    if ($c.hasBatchHint) { $batchOrEager++ } else { $realNPlusOne++ }
}

$result = @{
    candidates = $script:candidates
    counts = @{
        scannedFiles = $scannedFiles
        totalCandidates = $script:candidates.Count
        byVerdict = @{
            realNPlusOne = $realNPlusOne
            batchOrEager = $batchOrEager
        }
    }
}

Write-Output "=== N+1 Hunter Complete ==="
Write-Output "  Files scanned: $scannedFiles"
Write-Output "  Candidates found: $($script:candidates.Count)"
Write-Output "  Real N+1: $($result.counts.byVerdict.realNPlusOne)"
Write-Output "  Batch/Eager: $($result.counts.byVerdict.batchOrEager)"

Write-Output ($result | ConvertTo-Json -Depth 5)
exit 0
