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

# Patterns to find logger calls across languages.
$logCallPatterns = @(
    @{ regex='console\.(?:log|error|warn|info|debug|trace)\s*\('; kind='console' },
    @{ regex='logger\.(?:info|error|warn|debug|trace|log)\s*\('; kind='logger' },
    @{ regex='log\.(?:info|error|warn|debug|trace)\s*\('; kind='log' },
    @{ regex='Logger\.(?:info|error|warn|debug|trace)\s*\('; kind='Logger' },
    @{ regex='Log\.(?:info|error|warn|debug|trace)\s*\('; kind='Log' },
    @{ regex='log\.(?:Information|Error|Warning|Debug|Trace)\s*\('; kind='log-csharp' },
    @{ regex='logging\.(?:info|error|warn|debug|exception)\s*\('; kind='logging-py' },
    @{ regex='logger\.(?:log|printf|fatal)\s*\('; kind='logger-alt' }
)

# User-input indicators in log-call arguments.
$userInputPatterns = @(
    'req\.body',
    'req\.query',
    'req\.params',
    'request\.body',
    'request\.query',
    'request\.params',
    'event\.body',
    'message\.body',
    'input',
    'userInput',
    'user_input',
    'user\.input',
    'body\b',
    'params\b',
    'query\b',
    'payload\b'
)

# Sensitive-data keywords in arguments.
$sensitivePatterns = @(
    'password',
    'secret',
    'token',
    'api[_-]?key',
    'auth',
    'session',
    'cookie',
    'credit',
    'ssn',
    'email'
)

# Heuristic: does line have string concatenation with variable?
# Matches pattern like "... " + varName or "text " + req.body
$unsanitizedPlusPattern = '["\x27][^"\x27]*["\x27]\s*\+'

# Heuristic: does line have template literal with interpolation?
# (backtick string with ${...} containing a non-literal)
$unsanitizedTemplatePattern = '`[^`]*\$\{[^"\x27`0-9]'

$findings = @()
$linesScanned = 0

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
        $content = Get-Content -LiteralPath $fn -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $rel = $fn.Substring($ProjectDir.Length).TrimStart('\')
        $lines = $content -split "`n"
        $linesScanned += $lines.Count
        for ($li = 0; $li -lt $lines.Count; $li++) {
            $ln = $lines[$li]
            foreach ($r in $logCallPatterns) {
                $m = [regex]::Match($ln, $r.regex)
                if (-not $m.Success) { continue }
                $start = $m.Index
                $end = $start
                $depth = 0
                $inString = $null
                # Read until matching close-paren, respecting nested parens and strings.
                for ($ci = $start; $ci -lt $ln.Length; $ci++) {
                    $ch = $ln[$ci]
                    if ($inString) {
                        if ($ch -eq $inString -and ($ci -eq 0 -or $ln[$ci - 1] -ne '\')) { $inString = $null }
                    } elseif ($ch -eq '"' -or $ch -eq "'" -or $ch -eq '`') {
                        $inString = $ch
                    } elseif ($ch -eq '(') {
                        $depth++
                    } elseif ($ch -eq ')') {
                        $depth--
                        if ($depth -eq 0) { $end = $ci; break }
                    }
                }
                $callText = $ln.Substring($start, $end - $start + 1).Trim()
                $lineLower = $ln.ToLower()

                # Detect user input sources in this line.
                $userSources = @()
                foreach ($up in $userInputPatterns) {
                    if ($lineLower -match $up) {
                        $userSources += $matches[0]
                    }
                }

                # Detect sensitive keywords.
                $sensitiveKeys = @()
                foreach ($sp in $sensitivePatterns) {
                    if ($lineLower -match $sp) {
                        $sensitiveKeys += $matches[0]
                    }
                }

                # Detect unsanitized patterns.
                $hasPlusConcat = $ln -match $unsanitizedPlusPattern
                $hasTemplateInterp = $ln -match $unsanitizedTemplatePattern

                # Has user input AND unsanitized => CRLF risk.
                $hasCRLF = ($userSources.Count -gt 0) -and ($hasPlusConcat -or $hasTemplateInterp)

                $findings += @{
                    file = $rel
                    line = $li + 1
                    callText = ($callText -replace '\s+', ' ')
                    hasUserInput = ($userSources.Count -gt 0)
                    hasSensitiveData = ($sensitiveKeys.Count -gt 0)
                    userInputSources = $userSources
                    sensitiveKeys = $sensitiveKeys
                    unsanitizedPlus = $hasPlusConcat
                    unsanitizedTemplate = $hasTemplateInterp
                    hasCRLFRisk = $hasCRLF
                }
            }
        }
    }
}

Write-Output "=== Log Injection Scan Complete ==="
$fileSet = @($findings | ForEach-Object { $_.file } | Select-Object -Unique)
$userInputFindings = @($findings | Where-Object { $_.hasUserInput })
$sensitiveFindings = @($findings | Where-Object { $_.hasSensitiveData })
$crlfFindings = @($findings | Where-Object { $_.hasCRLFRisk })
Write-Output "  Files: $($fileSet.Count)"
Write-Output "  Lines scanned: $linesScanned"
Write-Output "  Total log statements: $($findings.Count)"
Write-Output "  With user input: $($userInputFindings.Count)"
Write-Output "  With sensitive data: $($sensitiveFindings.Count)"
Write-Output "  With CRLF injection risk: $($crlfFindings.Count)"

$result = @{
    findings = $findings
    counts = @{
        files = $fileSet.Count
        linesScanned = $linesScanned
        totalLogStatements = $findings.Count
        withUserInput = $userInputFindings.Count
        withSensitiveData = $sensitiveFindings.Count
        withCRLFRisk = $crlfFindings.Count
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
