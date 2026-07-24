[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('ts', 'tsx', 'js', 'jsx', 'py', 'cs', 'java'),

    [string[]]$Exclude = @()
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir '$ProjectDir' does not exist."
    exit 1
}

$ProjectDir = Resolve-Path -LiteralPath $ProjectDir -ErrorAction Stop

$assumptions = [System.Collections.ArrayList]@()
$files = Get-ChildItem -Path $ProjectDir -Recurse -File | Where-Object {
    $ext = $_.Extension.TrimStart('.').ToLower()
    $Extensions -contains $ext
}

function Get-Lines {
    param([string]$Content)
    return [regex]::Split($Content, '\r?\n')
}

function Get-DataOrigin {
    param([string]$Content, [int]$LineNumber)
    $lines = Get-Lines $Content
    $windowStart = [Math]::Max(0, $LineNumber - 10)
    $windowEnd = [Math]::Min($LineNumber, $lines.Count - 1)
    $sliced = ($lines[$windowStart..$windowEnd] -join ' ')
    if ($sliced -match '(fetch|axios\.get|http\.get|axios\.post|http\.post|readFile|readFileSync|parse\(|fromJSON|input|request|response|req\.body|ctx\.request)') {
        return 'external'
    }
    return 'internal'
}

function Get-CodeSnippet {
    param([string]$Content, [int]$LineNumber)
    $lines = Get-Lines $Content
    $start = [Math]::Max(0, $LineNumber - 1)
    $end = [Math]::Min($lines.Length - 1, $LineNumber + 1)
    $sliced = $lines[$start..$end] -join [System.Environment]::NewLine
    return $sliced.Trim()
}

function HasValidation {
    param([string]$Content, [int]$LineNumber)
    $lines = Get-Lines $Content
    $windowStart = [Math]::Max(0, $LineNumber - 15)
    $windowEnd = [Math]::Min(($lines).Length - 1, $LineNumber + 5)
    $sliced = ($lines[$windowStart..$windowEnd] -join ' ')
    $patterns = @(
        'try\s*\{',
        'catch\s*\(',
        '\.safeParse\(',
        'z\.object\(',
        'yup\.object\(',
        'io-ts',
        '\w+Schema\.parse\(',
        'if\s*\([^)]*\bnull\b[^)]*\)',
        'if\s*\([^)]*\bundefined\b[^)]*\)',
        '\?\?',
        '\|\|',
        '\.length\s*[>!=]',
        'Array\.isArray',
        '\?\.'
    )
    foreach ($p in $patterns) {
        if ($sliced -match $p) {
            return $true
        }
    }
    return $false
}

# Regex patterns per kind
$castPatterns = @(
    [regex]::new('\bas\s+(string|number|boolean|any|object|\[\])\b'),
    [regex]::new('<(?:\s*(?:string|number|boolean|any|object)\s*)>'),
    [regex]::new('\bcast\s*<\w+>')
)

$jsonParseRe = [regex]::new('JSON\.parse\s*\(')
$anyTypeRe = [regex]::new(':\s*any\b')
$anyAsRe = [regex]::new('as\s+any\b')
$optionalChainRe = [regex]::new('\?\.\s*[a-zA-Z_]\w*')
$arrayIndexRe = [regex]::new('\b(\w+)\s*\[\s*(\d+|i\w*|index\w*)\s*\]')
$typeGuardRe = [regex]::new('typeof\s+\w+\s*===\s*"(?:string|number|boolean|object|undefined)"')
$instanceofRe = [regex]::new('\binstanceof\s+\w+')
$destructureRe = [regex]::new('const\s*\{\s*([^}]+)\s*\}\s*=\s*(\w+)')

foreach ($file in $files) {
    $relPath = $file.FullName.Substring($ProjectDir.Length).TrimStart('\', '/')
    $content = Get-Content -Path $file.FullName -Raw -Encoding UTF8
    if (-not $content) { continue }
    $lines = Get-Lines $content

    # --- 1. Type assertions / casts ---
    for ($i = 0; $i -lt $lines.Count; $i++) {
        foreach ($re in $castPatterns) {
            if ($lines[$i] -match $re) {
                $null = $assumptions.Add([PSCustomObject]@{
                    file = $relPath
                    line = $i + 1
                    kind = 'cast'
                    origin = Get-DataOrigin -Content $content -LineNumber $i
                    hasValidation = HasValidation -Content $content -LineNumber $i
                    codeSnippet = Get-CodeSnippet -Content $content -LineNumber $i
                })
            }
        }
    }

    # --- 2. JSON.parse usage ---
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $jsonParseRe) {
            if ($lines[$i] -match '(?:const|let|var)\s+(\w+)\s*=\s*JSON\.parse') {
                $varName = $Matches[1]
                for ($j = $i + 1; $j -lt [Math]::Min($i + 6, $lines.Count); $j++) {
                    if ($lines[$j] -match "${varName}\.\w+") {
                        $null = $assumptions.Add([PSCustomObject]@{
                            file = $relPath
                            line = $i + 1
                            kind = 'parse'
                            origin = 'external'
                            hasValidation = HasValidation -Content $content -LineNumber $i
                            codeSnippet = Get-CodeSnippet -Content $content -LineNumber $i
                        })
                        break
                    }
                }
            }
        }
    }

    # --- 3. API response without validation ---
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '(fetch|axios\.get|http\.get)\s*\(') {
            $apiVar = $null
            if ($lines[$i] -match '(?:const|let|var)\s+(\w+)\s*=\s*await\s+(fetch|axios\.get|http\.get)') {
                $apiVar = $Matches[1]
            }
            if ($apiVar) {
                for ($j = $i + 1; $j -lt [Math]::Min($i + 8, $lines.Count); $j++) {
                    if ($lines[$j] -match "${apiVar}\.(?:data|json)") {
                        $null = $assumptions.Add([PSCustomObject]@{
                            file = $relPath
                            line = $i + 1
                            kind = 'unchecked-access'
                            origin = 'external'
                            hasValidation = HasValidation -Content $content -LineNumber $i
                            codeSnippet = Get-CodeSnippet -Content $content -LineNumber $i
                        })
                        break
                    }
                }
            }
        }
    }

    # --- 4. any typed variable usage ---
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $anyTypeRe -or $lines[$i] -match $anyAsRe) {
            $windowEnd = [Math]::Min($i + 3, $lines.Count - 1)
            for ($j = $i; $j -le $windowEnd; $j++) {
                if ($lines[$j] -match '\.\w+') {
                    $hasOptChain = $lines[$j] -match '\?\.'
                    $null = $assumptions.Add([PSCustomObject]@{
                        file = $relPath
                        line = $i + 1
                        kind = 'any-usage'
                        origin = Get-DataOrigin -Content $content -LineNumber $i
                        hasValidation = $hasOptChain -or (HasValidation -Content $content -LineNumber $i)
                        codeSnippet = Get-CodeSnippet -Content $content -LineNumber $i
                    })
                    break
                }
            }
        }
    }

    # --- 5. Optional chaining (always safe) ---
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $optionalChainRe) {
            $null = $assumptions.Add([PSCustomObject]@{
                file = $relPath
                line = $i + 1
                kind = 'optional-chain'
                origin = Get-DataOrigin -Content $content -LineNumber $i
                hasValidation = $true
                codeSnippet = Get-CodeSnippet -Content $content -LineNumber $i
            })
        }
    }

    # --- 6. Array index without length check ---
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $arrayIndexRe) {
            $arrName = $Matches[1]
            $hasLengthCheck = $false
            $windowStart = [Math]::Max(0, $i - 5)
            for ($j = $windowStart; $j -lt $i; $j++) {
                if ($lines[$j] -match "${arrName}\.length") {
                    $hasLengthCheck = $true
                    break
                }
            }
            $isOptional = $lines[$i] -match "${arrName}\?"
            if (-not $hasLengthCheck -and -not $isOptional) {
                $null = $assumptions.Add([PSCustomObject]@{
                    file = $relPath
                    line = $i + 1
                    kind = 'array-index'
                    origin = Get-DataOrigin -Content $content -LineNumber $i
                    hasValidation = HasValidation -Content $content -LineNumber $i
                    codeSnippet = Get-CodeSnippet -Content $content -LineNumber $i
                })
            }
        }
    }

    # --- 7. Unchecked instanceof/typeof ---
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $typeGuardRe -or $lines[$i] -match $instanceofRe) {
            $hasElse = $false
            if ($i + 1 -lt $lines.Count) {
                for ($j = $i + 1; $j -lt [Math]::Min($i + 15, $lines.Count); $j++) {
                    $trimmed = $lines[$j].Trim()
                    if ($trimmed -match '^\}\s*else' -or $trimmed -match '^else\b') {
                        $hasElse = $true
                        break
                    }
                    if ($trimmed -match '^\}') {
                        break
                    }
                }
            }
            if (-not $hasElse) {
                $null = $assumptions.Add([PSCustomObject]@{
                    file = $relPath
                    line = $i + 1
                    kind = 'type-guard'
                    origin = Get-DataOrigin -Content $content -LineNumber $i
                    hasValidation = HasValidation -Content $content -LineNumber $i
                    codeSnippet = Get-CodeSnippet -Content $content -LineNumber $i
                })
            }
        }
    }

    # --- 8. Destructuring without default ---
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match $destructureRe) {
            $destructureContent = $Matches[1]
            $sourceVar = $Matches[2]
            $hasDefault = $destructureContent -match '\b\w+\s*=\s*\S'
            $sourceHasFallback = $sourceVar -match '\|\|' -or $sourceVar -match '\?\?'
            if (-not $hasDefault -and -not $sourceHasFallback) {
                $null = $assumptions.Add([PSCustomObject]@{
                    file = $relPath
                    line = $i + 1
                    kind = 'destructuring'
                    origin = Get-DataOrigin -Content $content -LineNumber $i
                    hasValidation = HasValidation -Content $content -LineNumber $i
                    codeSnippet = Get-CodeSnippet -Content $content -LineNumber $i
                })
            }
        }
    }
}

# --- Risk classification ---
$crashRisk = [System.Collections.ArrayList]@()
$dataLoss = [System.Collections.ArrayList]@()
$safe = [System.Collections.ArrayList]@()

foreach ($a in $assumptions) {
    if ($a.hasValidation -eq $true) {
        $null = $safe.Add($a)
    } elseif ($a.origin -eq 'external') {
        $null = $crashRisk.Add($a)
    } elseif ($a.kind -in @('cast', 'array-index', 'any-usage')) {
        $null = $crashRisk.Add($a)
    } else {
        $null = $dataLoss.Add($a)
    }
}

$output = @{
    assumptions = $assumptions | ForEach-Object {
        $risk = if ($_.hasValidation -eq $true) { 'safe' }
                elseif ($_.origin -eq 'external') { 'crash' }
                elseif ($_.kind -in @('cast', 'array-index', 'any-usage')) { 'crash' }
                else { 'data-loss' }
        @{
            file = $_.file
            line = $_.line
            kind = $_.kind
            origin = $_.origin
            hasValidation = $_.hasValidation
            risk = $risk
            codeSnippet = $_.codeSnippet
        }
    }
    counts = @{
        total = $assumptions.Count
        'crash-risk' = $crashRisk.Count
        'data-loss' = $dataLoss.Count
        safe = $safe.Count
    }
}

$jsonOutput = $output | ConvertTo-Json -Depth 3
Write-Output $jsonOutput

Write-Output '=== TYPE-ASSUMPTION-SCAN ==='
Write-Output "Total assumptions found: $($assumptions.Count)"
Write-Output "Crash risk: $($crashRisk.Count)"
Write-Output "Data loss: $($dataLoss.Count)"
Write-Output "Safe (validated): $($safe.Count)"