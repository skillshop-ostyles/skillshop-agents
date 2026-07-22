[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ps1,*.py,*.js,*.ts,*.jsx,*.tsx,*.rb,*.php,*.java,*.go,*.cs",

    [string]$Exclude = "",

    [string]$MinSeverity = "low"
)

$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

$extList = $Extensions -split ',' | ForEach-Object { $_.Trim() }
$excludeList = if ($Exclude) { $Exclude -split ',' | ForEach-Object { $_.Trim() } } else { @() }

$severityLevels = @{ high = 3; medium = 2; low = 1 }
$minLevel = $severityLevels[$MinSeverity]
if (-not $minLevel) { $minLevel = 1 }

# -- Input surface regex maps per extension --
$surfacePatterns = @{
    'http-query' = @(
        @{ pattern = 'req\.query'; langs = @('.js','.ts','.jsx','.tsx') }
        @{ pattern = 'c\.req\.query'; langs = @('.js','.ts','.jsx','.tsx') }
        @{ pattern = 'searchParams\.get\b'; langs = @('.js','.ts','.jsx','.tsx') }
        @{ pattern = 'request\.GET'; langs = @('.py') }
        @{ pattern = 'request\.query_string'; langs = @('.py') }
        @{ pattern = 'request\.args'; langs = @('.py') }
        @{ pattern = 'Request\.Query'; langs = @('.cs') }
        @{ pattern = '@RequestParam'; langs = @('.java') }
        @{ pattern = 'r\.URL\.Query'; langs = @('.go') }
        @{ pattern = '\$_GET'; langs = @('.php') }
        @{ pattern = 'params\[|params\.'; langs = @('.rb') }
    )
    'http-body' = @(
        @{ pattern = 'req\.body'; langs = @('.js','.ts','.jsx','.tsx') }
        @{ pattern = 'c\.req\.body'; langs = @('.js','.ts','.jsx','.tsx') }
        @{ pattern = 'request\.json'; langs = @('.js','.ts','.jsx','.tsx') }
        @{ pattern = 'request\.text'; langs = @('.js','.ts','.jsx','.tsx') }
        @{ pattern = 'request\.formData'; langs = @('.js','.ts','.jsx','.tsx') }
        @{ pattern = 'request\.form'; langs = @('.py') }
        @{ pattern = 'request\.json'; langs = @('.py') }
        @{ pattern = 'request\.data'; langs = @('.py') }
        @{ pattern = '\[FromBody\]'; langs = @('.cs') }
        @{ pattern = '@RequestBody'; langs = @('.java') }
        @{ pattern = '\$_POST'; langs = @('.php') }
    )
    'http-params' = @(
        @{ pattern = 'req\.params'; langs = @('.js','.ts','.jsx','.tsx') }
        @{ pattern = 'c\.req\.param'; langs = @('.js','.ts','.jsx','.tsx') }
        @{ pattern = 'c\.Param'; langs = @('.go') }
        @{ pattern = '@PathVariable'; langs = @('.java') }
        @{ pattern = '\[FromRoute\]'; langs = @('.cs') }
    )
    'http-headers' = @(
        @{ pattern = 'req\.headers'; langs = @('.js','.ts','.jsx','.tsx') }
        @{ pattern = 'c\.req\.header'; langs = @('.js','.ts','.jsx','.tsx') }
        @{ pattern = 'request\.headers\.get\b'; langs = @('.js','.ts','.jsx','.tsx') }
        @{ pattern = 'request\.headers'; langs = @('.py') }
        @{ pattern = 'Request\.Headers'; langs = @('.cs') }
        @{ pattern = 'r\.Header'; langs = @('.go') }
        @{ pattern = 'getallheaders'; langs = @('.php') }
        @{ pattern = '@RequestHeader'; langs = @('.java') }
        @{ pattern = 'request\.env\.fetch\(|env\.fetch\('; langs = @('.rb') }
    )
    'cli-args' = @(
        @{ pattern = 'process\.argv'; langs = @('.js','.ts','.jsx','.tsx') }
        @{ pattern = 'sys\.argv'; langs = @('.py') }
        @{ pattern = '\$args'; langs = @('.ps1') }
        @{ pattern = 'os\.Args'; langs = @('.go') }
        @{ pattern = '\$argv'; langs = @('.php') }
        @{ pattern = 'args\['; langs = @('.rb') }
        @{ pattern = 'Environment\.GetCommandLineArgs|args\[|Args\['; langs = @('.cs') }
        @{ pattern = 'args\[|new\s+String\[\]'; langs = @('.java') }
    )
    'env-var' = @(
        @{ pattern = 'process\.env\.'; langs = @('.js','.ts','.jsx','.tsx') }
        @{ pattern = 'process\.env\[|process\.env\.\w+'; langs = @('.js','.ts','.jsx','.tsx') }
        @{ pattern = 'c\.env\.'; langs = @('.js','.ts','.jsx','.tsx') }
        @{ pattern = 'os\.environ(?:\.get)?'; langs = @('.py') }
        @{ pattern = '\$env:'; langs = @('.ps1') }
        @{ pattern = 'os\.Getenv|os\.LookupEnv'; langs = @('.go') }
        @{ pattern = 'getenv\(|_ENV\['; langs = @('.php') }
        @{ pattern = 'ENV\[|fetch\(env'; langs = @('.rb') }
        @{ pattern = 'GetEnvironmentVariable|Environment\.GetEnvironmentVariable'; langs = @('.cs') }
        @{ pattern = 'System\.getenv|env\.get'; langs = @('.java') }
    )
    'file-read' = @(
        @{ pattern = 'fs\.readFile|fs\.readFileSync|fs\.read\b'; langs = @('.js','.ts','.jsx','.tsx') }
        @{ pattern = 'open\(|\.read\(|file_get_contents'; langs = @('.py') }
        @{ pattern = 'Get-Content|Read-Host'; langs = @('.ps1') }
        @{ pattern = 'ioutil\.ReadFile|os\.ReadFile|bufio\.'; langs = @('.go') }
        @{ pattern = 'file_get_contents|fread|fgets|file\('; langs = @('.php') }
        @{ pattern = 'File\.Read|StreamReader|Console\.Read'; langs = @('.cs') }
        @{ pattern = 'Files\.read|BufferedReader|FileInputStream'; langs = @('.java') }
        @{ pattern = 'File\.read|IO\.read|File\.open'; langs = @('.rb') }
    )
    'stdin' = @(
        @{ pattern = 'readline|process\.stdin'; langs = @('.js','.ts','.jsx','.tsx') }
        @{ pattern = 'input\(|sys\.stdin'; langs = @('.py') }
        @{ pattern = 'Read-Host|\[Console\]::In|Console\.Read'; langs = @('.ps1') }
        @{ pattern = 'bufio\.Scanner|os\.Stdin'; langs = @('.go') }
        @{ pattern = 'fgets\(STDIN|readline\('; langs = @('.php') }
        @{ pattern = 'Console\.In|Console\.ReadLine'; langs = @('.cs') }
        @{ pattern = 'System\.in|Scanner\('; langs = @('.java') }
        @{ pattern = 'STDIN|gets\('; langs = @('.rb') }
    )
}

$validationPatterns = @(
    '\.test\s*\(',
    '\.match\s*\(',
    '\.includes\s*\(',
    '\.startsWith\s*\(',
    '\.search\s*\(',
    'indexOf\s*\(',
    'typeof\s+\w+\s*===',
    'instanceof\b',
    '\.length\s*[<>!]',
    '\.Count\s*[<>!]',
    'len\(\w+\)\s*[<>!]',
    'sanitize',
    'escape\s*\(',
    'purify',
    'strip_tags',
    'htmlspecialchars',
    'addslashes',
    'Joi\.',
    'z\.\w+\.',
    'yup\.',
    'Validator\.',
    'validator\b',
    'class-validator',
    'FluentValidation',
    '\.isValid',
    '\.validate\b',
    'TryParse',
    'Number\s*\(',
    'parseInt\s*\(',
    'parseFloat\s*\(',
    'int\s*\(',
    'float\s*\(',
    'intval\s*\(',
    'floatval\s*\(',
    'str\(|string\(',
    'null\s*==\s*\w+',
    '\w+\s*[=!]=\s*null',
    '!\w+\s*\)',
    'if\s*\(!\w+',
    'if\s+not\s+\w+',
    'guard\b',
    '\.trim\s*\(',
    '\.replace\s*\('
)

$sinkPatterns = @{
    'sql' = @('query\b', 'execute\b', 'run\b', 'sql\b', 'SELECT\b', 'INSERT\b', 'UPDATE\b', 'DELETE\b')
    'shell' = @('exec\b', 'spawn\b', 'shell\b', 'system\b', 'popen\b', 'child_process', 'subprocess')
    'file-write' = @('writeFile\b', 'WriteFile', 'fwrite\b', 'fputs\b', 'file_put_contents', 'open\(.*w')
    'html' = @('innerHTML\b', 'document\.write\b', 'response\.write\b', 'echo\b', 'print\b', 'Render\b')
    'log' = @('console\.log\b', 'logger\.\w+', 'log\.info\b', 'log\.error\b', 'print\b', 'echo\b', 'Write-Output\b', 'Write-Host\b')
}

function Get-SourceFiles {
    param([string]$Dir)
    $files = @()
    foreach ($ext in $extList) {
        $found = Get-ChildItem -Path $Dir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue
        foreach ($f in $found) {
            $skip = $false
            foreach ($ex in $excludeList) {
                if ($f.FullName -like "*$ex*") { $skip = $true; break }
            }
            if (-not $skip -and $f.FullName -notlike "*\node_modules\*" -and $f.FullName -notlike "*\.git\*" -and $f.FullName -notlike "*\venv\*" -and $f.FullName -notlike "*\__pycache__\*" -and $f.FullName -notlike "*\.wrangler*") {
                $files += $f
            }
        }
    }
    return $files
}

function Get-Context {
    param([string[]]$Lines, [int]$LineIndex, [int]$Radius = 5)
    $start = [Math]::Max(0, $LineIndex - $Radius)
    $end = [Math]::Min($Lines.Length - 1, $LineIndex + $Radius)
    $ctx = @()
    for ($i = $start; $i -le $end; $i++) {
        $prefix = if ($i -eq $LineIndex) { ">>>" } else { "   " }
        $ctx += "$prefix $($Lines[$i])"
    }
    return ($ctx -join "`n")
}

function Test-NearbyValidation {
    param([string[]]$Lines, [int]$LineIndex, [int]$Radius = 10)
    $start = [Math]::Max(0, $LineIndex - $Radius)
    $end = [Math]::Min($Lines.Length - 1, $LineIndex + $Radius)
    $found = @()
    for ($i = $start; $i -le $end; $i++) {
        foreach ($vp in $validationPatterns) {
            if ($Lines[$i] -match $vp) {
                $found += "$vp (line $($i+1))"
            }
        }
    }
    return ($found | Select-Object -Unique)
}

function Get-DetectedSinks {
    param([string[]]$Lines, [int]$LineIndex, [int]$Radius = 5)
    $start = [Math]::Max(0, $LineIndex - $Radius)
    $end = [Math]::Min($Lines.Length - 1, $LineIndex + $Radius)
    $sinks = @{}
    for ($i = $start; $i -le $end; $i++) {
        foreach ($sinkType in $sinkPatterns.Keys) {
            foreach ($sp in $sinkPatterns[$sinkType]) {
                if ($Lines[$i] -match $sp) {
                    if (-not $sinks.ContainsKey($sinkType)) { $sinks[$sinkType] = @() }
                    $sinks[$sinkType] += "$sp (line $($i+1))"
                }
            }
        }
    }
    return $sinks
}

function Get-Severity {
    param([System.Collections.IDictionary]$Sinks, [string[]]$ValidationFound)
    if ($ValidationFound.Count -gt 0) { return "low" }
    $highSinks = @('sql', 'shell', 'file-write', 'html')
    $hasHigh = $false
    foreach ($hs in $highSinks) { if ($Sinks.ContainsKey($hs)) { $hasHigh = $true; break } }
    if ($Sinks.ContainsKey('log')) { return "medium" }
    if ($hasHigh) { return "high" }
    return "medium"
}

$files = Get-SourceFiles -Dir $ProjectDir
$allSurfaces = @()
$allFindings = @()
$findingId = 0

foreach ($f in $files) {
    $rel = $f.FullName.Substring($ProjectDir.Length).TrimStart('\')
    $ext = $f.Extension.ToLower()

    try {
        $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
    } catch { continue }
    $lines = $content -split "`n"

    foreach ($surfaceType in $surfacePatterns.Keys) {
        foreach ($sp in $surfacePatterns[$surfaceType]) {
            if ($sp.langs -contains $ext) {
                $ms = [regex]::Matches($content, $sp.pattern)
                foreach ($m in $ms) {
                    $lineNum = ($content.Substring(0, $m.Index) -split "`n").Length - 1
                    if ($lineNum -lt 0 -or $lineNum -ge $lines.Length) { continue }

                    $context = Get-Context -Lines $lines -LineIndex $lineNum
                    $validation = Test-NearbyValidation -Lines $lines -LineIndex $lineNum
                    $sinks = Get-DetectedSinks -Lines $lines -LineIndex $lineNum
                    $severity = Get-Severity -Sinks $sinks -ValidationFound $validation

                    $surface = @{
                        file = $rel
                        line = $lineNum + 1
                        expression = $m.Value
                        type = $surfaceType
                        validationPresent = ($validation.Count -gt 0)
                    }
                    $allSurfaces += $surface

                    $svLevel = $severityLevels[$severity]
                    if ($svLevel -ge $minLevel) {
                        $classification = if ($validation.Count -eq 0) { "unvalidated" } else { "validated" }
                        $sinkTypes = @($sinks.Keys)
                        $confidence = if ($sinkTypes.Count -gt 0) { "high" } else { "medium" }

                        $finding = @{
                            id = $findingId
                            file = $rel
                            line = $lineNum + 1
                            surface = $m.Value
                            surfaceType = $surfaceType
                            context = $context
                            nearbyValidation = $validation
                            classification = $classification
                            severity = $severity
                            sinkType = if ($sinkTypes.Count -gt 0) { $sinkTypes -join ',' } else { "none" }
                            confidence = $confidence
                        }
                        $allFindings += $finding
                        $findingId++
                    }
                }
            }
        }
    }
}

# -- Stats --
$byType = @{}
$bySeverity = @{ high = 0; medium = 0; low = 0 }
$unvalidatedCount = 0
foreach ($f in $allFindings) {
    $t = $f.surfaceType
    if (-not $byType.ContainsKey($t)) { $byType[$t] = 0 }
    $byType[$t]++
    if ($f.classification -eq "unvalidated") { $unvalidatedCount++ }
}
foreach ($f in $allFindings) { $bySeverity[$f.severity]++ }

$stats = @{
    totalSurfaces = $allSurfaces.Count
    unvalidated = $unvalidatedCount
    underValidated = 0
    validated = ($allSurfaces.Count - $unvalidatedCount)
    byType = $byType
    bySeverity = $bySeverity
}

$output = @{
    findings = $allFindings
    inputSurfaces = $allSurfaces
    stats = $stats
}

$json = $output | ConvertTo-Json -Depth 5
Write-Output $json

# Console summary
Write-Output "=== Input Validation Scan Complete ==="
Write-Output "  Files scanned: $($files.Count)"
Write-Output "  Input surfaces found: $($allSurfaces.Count)"
foreach ($t in ($byType.Keys | Sort-Object)) {
    Write-Output "    $t : $($byType[$t])"
}
Write-Output "  Findings: $($allFindings.Count) (unvalidated: $unvalidatedCount)"
Write-Output "    high: $($bySeverity.high) | medium: $($bySeverity.medium) | low: $($bySeverity.low)"
Write-Output ""
Write-Output "  Next step: run LLM analysis via SKILL.md steps"
