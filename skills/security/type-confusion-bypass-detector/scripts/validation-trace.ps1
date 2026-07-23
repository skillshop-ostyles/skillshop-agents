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

# Validation patterns grouped by kind
$validationPatterns = @(
    @{ regex='typeof\s+\w+\s*===\s*[''"]string[''"]';            kind='type-check' },
    @{ regex='typeof\s+\w+\s*!==\s*[''"]undefined[''"]';        kind='type-check' },
    @{ regex='\.length\s*<\s*\d+';                               kind='length-check' },
    @{ regex='\.length\s*>\s*\d+';                               kind='length-check' },
    @{ regex='\.length\s*<=\s*\d+';                              kind='length-check' },
    @{ regex='\.length\s*>=\s*\d+';                              kind='length-check' },
    @{ regex='\.length\s*===\s*\d+';                             kind='length-check' },
    @{ regex='\.test\s*\(';                                      kind='regex-validation' },
    @{ regex='\.match\s*\(/';                                    kind='regex-validation' },
    @{ regex='\.replace\s*\(/.*?\/g';                            kind='sanitization' },
    @{ regex='\.replace\s*\(/.*?\/gi';                           kind='sanitization' },
    @{ regex='isinstance\s*\(\s*\w+\s*,\s*str\b';                kind='type-check' },
    @{ regex='isinstance\s*\(\s*\w+\s*,\s*int\b';                kind='type-check' },
    @{ regex='\.GetType\(\).*==\s*typeof\s*\(\w+\)';             kind='type-check' },
    @{ regex='x\s+is\s+string';                                  kind='type-check' },
    @{ regex='\.\w+\s+is\s+string';                              kind='type-check' },
    @{ regex='regex\.IsMatch';                                   kind='regex-validation' },
    @{ regex='re\.match';                                        kind='regex-validation' },
    @{ regex='re\.search';                                       kind='regex-validation' },
    @{ regex='re\.fullmatch';                                    kind='regex-validation' },
    @{ regex='strip_tags';                                       kind='sanitization' },
    @{ regex='html\.escape';                                     kind='sanitization' },
    @{ regex='sanitize-html';                                    kind='sanitization' },
    @{ regex='Joi\.object';                                      kind='schema-validation' },
    @{ regex='zod\.object';                                      kind='schema-validation' },
    @{ regex='yup\.object';                                      kind='schema-validation' },
    @{ regex='pydantic';                                         kind='schema-validation' },
    @{ regex='marshmallow';                                      kind='schema-validation' },
    @{ regex='DataAnnotations';                                  kind='schema-validation' },
    @{ regex='\[Required\]';                                     kind='schema-validation' },
    @{ regex='\[StringLength';                                   kind='schema-validation' },
    @{ regex='-eq\s+\$null';                                     kind='null-check' },
    @{ regex='-ne\s+\$null';                                     kind='null-check' },
    @{ regex='===?\s*null';                                      kind='null-check' },
    @{ regex='!==?\s*null';                                      kind='null-check' },
    @{ regex='\.includes';                                       kind='contains-check' },
    @{ regex='\.startsWith';                                     kind='prefix-check' },
    @{ regex='\.endsWith';                                       kind='suffix-check' },
    @{ regex='len\(.*?\)\s*[<>=]';                               kind='length-check' },
    @{ regex='str\.len\(.*?\)\s*[<>=]';                          kind='length-check' }
)

# Input sources
$inputSourcePatterns = @(
    @{ regex='req\.body';        source='express-body' },
    @{ regex='req\.query';       source='express-query' },
    @{ regex='req\.params';      source='express-params' },
    @{ regex='request\.body';    source='flask-body' },
    @{ regex='request\.get_json';source='flask-json' },
    @{ regex='request\.args';    source='flask-query' },
    @{ regex='event\.body';      source='lambda-body' },
    @{ regex='context\.args';    source='function-arg' },
    @{ regex='\bargs\b';         source='cli-arg' },
    @{ regex='\bargv\b';         source='cli-arg' },
    @{ regex='sys\.stdin';       source='stdin' },
    @{ regex='request\.form';    source='flask-form' },
    @{ regex='request\.files';   source='flask-file' },
    @{ regex='HttpRequest';      source='dotnet-request' },
    @{ regex='FromBody';         source='dotnet-body' },
    @{ regex='FromQuery';        source='dotnet-query' }
)

# Execution sinks
$sinkPatterns = @(
    @{ regex='\.find\s*\(';     sink='db-query' },
    @{ regex='\.findOne\s*\(';  sink='db-query' },
    @{ regex='\.findById\s*\('; sink='db-query' },
    @{ regex='db\.query';       sink='sql-query' },
    @{ regex='db\.execute';     sink='sql-query' },
    @{ regex='\.save\s*\(';     sink='orm-write' },
    @{ regex='\.create\s*\(';   sink='orm-write' },
    @{ regex='\.updateOne\s*\('; sink='orm-write' },
    @{ regex='\.insertOne\s*\('; sink='orm-write' },
    @{ regex='\.insertMany\s*\('; sink='orm-write' },
    @{ regex='exec\s*\(';       sink='shell-exec' },
    @{ regex='spawn\s*\(';      sink='shell-exec' },
    @{ regex='shell_exec';      sink='shell-exec' },
    @{ regex='subprocess\.run'; sink='shell-exec' },
    @{ regex='render_template_string'; sink='template-render' },
    @{ regex='dangerouslySetInnerHTML'; sink='dom-xss' },
    @{ regex='\.innerHTML';     sink='dom-xss' },
    @{ regex='\.ExecuteSql';    sink='sql-query' },
    @{ regex='ExecuteSqlCommand'; sink='sql-query' },
    @{ regex='\.Find\s*\(';     sink='db-query' },
    @{ regex='\.FirstOrDefault'; sink='db-query' },
    @{ regex='\.Where\s*\(';    sink='db-query' },
    @{ regex='\.RawQuery';      sink='sql-query' },
    @{ regex='\$where';         sink='nosql-injection' },
    @{ regex='where\s+.*?[''"]?\$[a-z]'; sink='nosql-injection' }
)

$findings = @()
$linesScanned = 0

function Test-DirectoryExcluded {
    param([string]$path)
    if ($path -match '[\\/]node_modules[\\/]|[\\/]\.git[\\/]|[\\/]venv[\\/]|[\\/]__pycache__[\\/]|[\\/]dist[\\/]|[\\/]build[\\/]|[\\/]bin[\\/]|[\\/]obj[\\/]') { return $true }
    if ($path -match '\.test\.|\.spec\.|-test\.|_test\.py|Test\.cs') { return $true }
    if ($path -match '[\\/]tests[\\/]') {
        if ($path -match '[\\/]fixtures[\\/]') { return $false }
        return $true
    }
    return $false
}

function Get-LinesAround {
    param([string[]]$lines, [int]$lineIndex, [int]$radius = 20)
    $start = [Math]::Max(0, $lineIndex - $radius)
    $end = [Math]::Min($lines.Count - 1, $lineIndex + $radius)
    return $lines[$start..$end] -join "`n"
}

foreach ($ext in ($Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    $items = Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue
    foreach ($i in $items) {
        $fn = $i.FullName
        if (Test-DirectoryExcluded $fn) { continue }
        $content = Get-Content -LiteralPath $fn -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $rel = $fn.Substring($ProjectDir.Length).TrimStart('\')
        $lines = $content -split "`n"
        $linesScanned += $lines.Count

        # Collect validation lines and input-source lines in this file
        $validationLines = @{}
        $inputSourceLines = @()
        $sinkLines = @()

        for ($li = 0; $li -lt $lines.Count; $li++) {
            $ln = $lines[$li]
            # Detect validation
            foreach ($p in $validationPatterns) {
                if ($ln -match $p.regex) {
                    if (-not $validationLines.ContainsKey($li)) {
                        $validationLines[$li] = @()
                    }
                    $validationLines[$li] += $p.kind
                }
            }
            # Detect input sources
            foreach ($p in $inputSourcePatterns) {
                if ($ln -match $p.regex) {
                    $inputSourceLines += @{ line = $li; source = $p.source }
                }
            }
            # Detect sinks
            foreach ($p in $sinkPatterns) {
                if ($ln -match $p.regex) {
                    $sinkLines += @{ line = $li; sink = $p.sink }
                }
            }
        }

        # Trace: for each input source, find nearby validations and sinks
        foreach ($inputSrc in $inputSourceLines) {
            $nearbyValidation = $null
            $nearbyValidationTypes = @()
            $minDist = 21

            # Look for validation within 20 lines of input source
            foreach ($vl in $validationLines.Keys) {
                $dist = [Math]::Abs($vl - $inputSrc.line)
                if ($dist -le 20 -and $dist -lt $minDist) {
                    $minDist = $dist
                    $nearbyValidation = $vl
                    $nearbyValidationTypes = $validationLines[$vl]
                }
            }

            # Look for sinks within 20 lines of input source
            $nearbySinks = @()
            foreach ($sl in $sinkLines) {
                $dist = [Math]::Abs($sl.line - $inputSrc.line)
                if ($dist -le 20) {
                    $nearbySinks += $sl
                }
            }

            if ($nearbySinks.Count -gt 0) {
                foreach ($sink in $nearbySinks) {
                    $validated = $nearbyValidation -ne $null
                    $contextBlock = Get-LinesAround -lines $lines -lineIndex $inputSrc.line -radius 3

                    $findings += @{
                        file = $rel
                        line = $inputSrc.line + 1
                        validationType = if ($validated) { ($nearbyValidationTypes -join ', ') } else { 'none' }
                        inputSource = $inputSrc.source
                        sinkType = $sink.sink
                        sinkLine = $sink.line + 1
                        sinkFound = $true
                        validated = $validated
                        context = $contextBlock
                    }
                }
            }
            else {
                # Input source without sink within 20 lines — still report
                $contextBlock = Get-LinesAround -lines $lines -lineIndex $inputSrc.line -radius 3
                $findings += @{
                    file = $rel
                    line = $inputSrc.line + 1
                    validationType = if ($nearbyValidation -ne $null) { ($nearbyValidationTypes -join ', ') } else { 'none' }
                    inputSource = $inputSrc.source
                    sinkType = 'none'
                    sinkLine = $null
                    sinkFound = $false
                    validated = $nearbyValidation -ne $null
                    context = $contextBlock
                }
            }
        }
    }
}

Write-Output "=== Validation Trace Complete ==="
$fileSet = @($findings | ForEach-Object { $_.file } | Select-Object -Unique)
$validatedCount = @($findings | Where-Object { $_.validated -eq $true }).Count
$unvalidatedCount = @($findings | Where-Object { $_.validated -eq $false }).Count
$sinkFoundCount = @($findings | Where-Object { $_.sinkFound -eq $true }).Count

Write-Output "  Files: $($fileSet.Count)"
Write-Output "  Lines scanned: $linesScanned"
Write-Output "  Data-flow paths: $($findings.Count)"
Write-Output "  With validation: $validatedCount"
Write-Output "  Without validation: $unvalidatedCount"
Write-Output "  Paths to sink: $sinkFoundCount"

$result = @{
    findings = $findings
    counts = @{
        files = $fileSet.Count
        totalPaths = $findings.Count
        validated = $validatedCount
        unvalidated = $unvalidatedCount
        pathsToSink = $sinkFoundCount
    }
    edgeCaseInputs = @('string', 'integer', 'object', 'null', 'array')
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
