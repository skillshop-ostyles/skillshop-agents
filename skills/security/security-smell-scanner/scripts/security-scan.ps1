[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ps1,*.py,*.js,*.ts,*.jsx,*.tsx,*.rb,*.php,*.java,*.go,*.cs,*.swift,*.kt",

    [string]$Exclude = ""
)

# Path validation BEFORE ErrorActionPreference (Write-Error would terminate otherwise)
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
            if (-not $skip -and $f.FullName -notlike "*\node_modules\*" -and $f.FullName -notlike "*\.git\*" -and $f.FullName -notlike "*\venv\*" -and $f.FullName -notlike "*\__pycache__\*") {
                $files += $f
            }
        }
    }
    return $files
}

function Get-Context {
    param([string[]]$Lines, [int]$LineIndex, [int]$Radius = 3)
    $start = [Math]::Max(0, $LineIndex - $Radius)
    $end = [Math]::Min($Lines.Length - 1, $LineIndex + $Radius)
    $ctx = @()
    for ($i = $start; $i -le $end; $i++) {
        $ctx += $Lines[$i]
    }
    return ($ctx -join "`n")
}

function Test-HasSanitizer {
    param([string[]]$Lines, [int]$LineIndex, [int]$Radius = 5)
    $start = [Math]::Max(0, $LineIndex - $Radius)
    $end = [Math]::Min($Lines.Length - 1, $LineIndex + $Radius)
    $combined = ""
    for ($i = $start; $i -le $end; $i++) {
        $combined += $Lines[$i] + " "
    }
    $sanitizePatterns = @(
        'sanitize', 'escape', 'encodeURI', 'encodeURIComponent',
        'htmlentities', 'htmlspecialchars', 'strip_tags',
        'filter_var', 'preg_replace', 'mysqli_real_escape_string',
        'pg_escape_string', 'sqlite_escape_string',
        'parametrize', 'parameterize', 'Parameterized',
        'placeholder', 'prepared.?statement', 'bind_param',
        'escapeString', 'sanitizeInput', 'validateInput',
        'DOMPurify', 'sanitize-html', 'xss-filters',
        'helmet', 'csp', 'Content-Security-Policy',
        'query\s*[:=]\s*"', '\.execute\(.*\?'
    )
    foreach ($p in $sanitizePatterns) {
        if ($combined -match $p) { return $true }
    }
    return $false
}

# Pattern definitions: [regex, severity, patternName, suggestedFix]
$patterns = @(
    # 1. SQL injection
    @{ Regex = '(?i)(SELECT\s+.*\s+FROM|INSERT\s+INTO|UPDATE\s+.*SET|DELETE\s+FROM).*["''`]?\s*[+$]|\$\{|\.format\(|f["'']|\%s|\?.*\+'; Severity = 'high'; Name = 'sql-injection'; Fix = 'Use parameterized queries (prepared statements) instead of string concatenation.' },
    # 2. XSS
    @{ Regex = '(?i)(innerHTML|outerHTML|dangerouslySetInnerHTML|v-html|insertAdjacentHTML)\s*[=:]'; Severity = 'high'; Name = 'xss'; Fix = 'Use textContent or a sanitization library (DOMPurify) before setting innerHTML.' },
    # 3. Command injection
    @{ Regex = '(?i)(exec\s*\(|execSync\s*\(|child_process|shell:\s*true|eval\s*\(|system\s*\(|popen\s*\(|subprocess\.)'; Severity = 'high'; Name = 'command-injection'; Fix = 'Avoid dynamic command construction. Use spawn() with argument array instead of shell: true.' },
    # 4. Path traversal
    @{ Regex = '(?i)((open|readFile|writeFile|unlink|rmdir|existsSync|readFileSync|writeFileSync|createReadStream|createWriteStream)\s*\([^)]*[\+\$\{][^)]*\))'; Severity = 'high'; Name = 'path-traversal'; Fix = 'Resolve and validate file paths. Restrict access to a known safe directory.' },
    # 5. Hardcoded credentials
    @{ Regex = '(?i)(password|passwd|api_key|apikey|secret|token|credential)\s*[:=]\s*["''][^"'']{4,}["'']'; Severity = 'medium'; Name = 'hardcoded-creds'; Fix = 'Move credentials to environment variables or a secrets manager. Never hardcode.' },
    # 6. Insecure defaults
    @{ Regex = '(?i)(secure:\s*false|ssl:\s*false|tls:\s*false|strict:\s*false|verify:\s*false|\bNODE_TLS_REJECT_UNAUTHORIZED\s*[=:]\s*0|rejectUnauthorized\s*:\s*false)'; Severity = 'high'; Name = 'insecure-defaults'; Fix = 'Enable security features. Set secure: true, verify certificates.' },
    # 7. IDOR (object-level access without auth)
    @{ Regex = '(?i)(req\.params\.\w+|req\.query\.\w+|request\.args\b|request\.params\.\w+|:id|/{[\w]+\})'; Severity = 'medium'; Name = 'idor'; Fix = 'Add authorization check before accessing object-level resources.' },
    # 8. Open redirect
    @{ Regex = '(?i)(redirect\s*\(|res\.redirect\s*\(|Location:\s*["'']|header\(["'']Location)'; Severity = 'medium'; Name = 'open-redirect'; Fix = 'Validate redirect targets against a whitelist. Do not accept user-controlled URLs.' },
    # 9. TOCTOU
    @{ Regex = '(?i)(exists|existsSync|stat|access)'; Severity = 'medium'; Name = 'toctou'; Fix = 'Use open() with O_CREAT and O_EXCL for atomic operations instead of check-then-act.' },
    # 10. Missing input validation (trust boundary)
    @{ Regex = '(?i)(req\.body|request\.json|req\.query|request\.args|\.form\b|$_GET|$_POST|\$_REQUEST)'; Severity = 'medium'; Name = 'missing-input-validation'; Fix = 'Validate and sanitize all external input at the trust boundary.' }
)

$files = Get-SourceFiles -Dir $ProjectDir
$findings = @()
$findingId = 0

foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($ProjectDir.Length).TrimStart('\')
    try {
        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $lines = $content -split "`n"
    } catch {
        continue
    }

    foreach ($pattern in $patterns) {
        $matches = [regex]::Matches($content, $pattern.Regex)
        foreach ($m in $matches) {
            $findingId++
            $lineNum = ($content.Substring(0, $m.Index) -split "`n").Length
            $lineIndex = $lineNum - 1
            $context = Get-Context -Lines $lines -LineIndex $lineIndex
            $hasSan = Test-HasSanitizer -Lines $lines -LineIndex $lineIndex

            # For ORM methods that match SQL pattern but are parameterized, mark as sanitized
            if ($pattern.Name -eq 'sql-injection') {
                $nearby = ($lines | Select-Object -Skip ([Math]::Max(0, $lineIndex - 3)) -First 7) -join ' '
                if ($nearby -match '(?i)(prisma|typeorm|sequelize|knex|drizzle|mikro-orm|entityManager|repository)\s*\.' -and $nearby -notmatch '\+\s*["'']|format\(|\[') {
                    $hasSan = $true
                }
            }

            # Extract evidence (the matched line)
            $evidLine = if ($lineIndex -lt $lines.Length) { $lines[$lineIndex].Trim() } else { "" }

            $finding = @{
                id = $findingId
                pattern = $pattern.Name
                severity = $pattern.Severity
                file = $relativePath
                line = $lineNum
                evidence = $evidLine.Substring(0, [Math]::Min(200, $evidLine.Length))
                context = $context.Substring(0, [Math]::Min(500, $context.Length))
                hasSanitizer = $hasSan
                suggestedFix = $pattern.Fix
            }

            # Redact credential values
            if ($pattern.Name -eq 'hardcoded-creds') {
                $finding.evidence = $finding.evidence -replace '["''][^"'']{4,}["'']', '"[REDACTED]"'
                $finding.context = $finding.context -replace '(password|passwd|api_key|apikey|secret|token|credential)\s*[:=]\s*["''][^"'']{4,}["'']', '$1 = "[REDACTED]"'
            }

            $findings += $finding
        }
    }
}

# Count stats
$total = $findings.Count
$highCount = ($findings | Where-Object { $_.severity -eq 'high' }).Count
$medCount = ($findings | Where-Object { $_.severity -eq 'medium' }).Count
$byPattern = @{}
$highestMed = $medCount

foreach ($f in $findings) {
    $p = $f.pattern
    if (-not $byPattern.ContainsKey($p)) { $byPattern[$p] = 0 }
    $byPattern[$p]++
}

$output = @{
    findings = $findings
    counts = @{
        total = $total
        bySeverity = @{ high = $highCount; medium = $medCount }
        byPattern = $byPattern
    }
    summary = "Found $total security smell(s): $highCount high, $medCount medium severity."
}

# JSON output
$json = $output | ConvertTo-Json -Depth 5
Write-Output $json

# Console summary
Write-Output "=== Security Smell Scan Complete ==="
Write-Output "  Scanned: $($files.Count) files in $ProjectDir"
Write-Output "  Findings: $total (high: $highCount, medium: $medCount)"
Write-Output "  By pattern:"
foreach ($p in $byPattern.GetEnumerator() | Sort-Object Name) {
    Write-Output "    $($p.Key): $($p.Value)"
}
Write-Output ""
Write-Output "  Next step: run LLM analysis via SKILL.md steps 4-5"
