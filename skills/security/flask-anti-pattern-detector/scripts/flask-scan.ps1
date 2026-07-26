[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.py",
    [string]$Exclude = ""
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

# --- Flask project detection ---
$projectIsFlask = $false
$flaskCheckFiles = @("requirements.txt", "Pipfile", "pyproject.toml", "setup.py", "setup.cfg")
foreach ($fname in $flaskCheckFiles) {
    $files = Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $fname -File -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
        if ($content -and $content -match 'flask') {
            $projectIsFlask = $true
            break
        }
    }
    if ($projectIsFlask) { break }
}

# Pattern registry per anti-pattern type
$patterns = @(
    @{ regex='SECRET_KEY\s*=\s*[''"]((?!os\.environ|os\.getenv).+?)[''"]'; type='hardcoded-secret'; severity='high' },
    @{ regex='app\.config\s*\[\s*[''"]SECRET_KEY[''"]\s*\]\s*=\s*[''"]((?!os\.environ|os\.getenv).+?)[''"]'; type='hardcoded-secret'; severity='high' },
    @{ regex='app\.run\(.*debug\s*=\s*True'; type='debug-mode'; severity='high' },
    @{ regex='DEBUG\s*=\s*True'; type='debug-mode'; severity='medium' },
    @{ regex='render_template_string\s*\('; type='unsafe-template'; severity='critical' },
    @{ regex='pickle\.loads?\s*\(.*request\.(?:data|files|form|args|get_json)'; type='pickle'; severity='critical' },
    @{ regex='pickle\.load\s*\(.*request\.'; type='pickle'; severity='critical' },
    @{ regex='eval\s*\(.*request\.(?:args|form|data|get_json|cookies|headers)'; type='eval-exec'; severity='critical' },
    @{ regex='exec\s*\(.*request\.(?:args|form|data|get_json|cookies|headers)'; type='eval-exec'; severity='critical' },
    @{ regex='session\s*\[\s*[''"]\w+[''"]\s*\]\s*=.*[''"]'; type='session'; severity='medium' },
    @{ regex='session\.permanent\s*=\s*True'; type='session'; severity='low' },
    @{ regex='db\.engine\.execute\s*\(\s*f[''"]'; type='sql-injection'; severity='critical' },
    @{ regex='db\.session\.execute\s*\(\s*text\s*\(\s*[''"]'; type='sql-injection'; severity='critical' },
    @{ regex='execute\s*\(\s*f[''"].*\{' ; type='sql-injection'; severity='critical' },
    @{ regex='request\.files\s*\[[''"]\w+[''"]\]\s*\.save\b'; type='unsafe-upload'; severity='medium' },
    @{ regex='request\.files\s*\[[''"]\w+[''"]\]\s*.*filename'; type='unsafe-upload'; severity='medium' },
    @{ regex='DEBUG_TB_ENABLED\s*=\s*True'; type='debug-toolbar'; severity='low' },
    @{ regex='DebugToolbarExtension\s*\('; type='debug-toolbar'; severity='low' }
)

# Severity ordering for output
$severityOrder = @{ 'critical' = 0; 'high' = 1; 'medium' = 2; 'low' = 3 }

$findings = @()
$linesScanned = 0

foreach ($ext in ($Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    $items = Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue
    foreach ($i in $items) {
        $fn = $i.FullName
        $accept = $true
        if ($fn -match '[\\/]node_modules[\\/]|[\\/]\.git[\\/]|[\\/]venv[\\/]|[\\/]__pycache__[\\/]|[\\/]dist[\\/]|[\\/]build[\\/]') { $accept = $false }
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
            foreach ($p in $patterns) {
                $m = [regex]::Match($ln, $p.regex)
                if ($m.Success) {
                    $findings += @{
                        file = $rel
                        line = $li + 1
                        patternType = $p.type
                        code = ($ln.Trim() -replace '\s+', ' ')
                        severity = $p.severity
                    }
                }
            }
        }
    }
}

# Sort: severity (critical first), then file, then line
$findings = $findings | Sort-Object @{Expression={$severityOrder[$_.severity]}}, file, line

Write-Output "=== Flask Anti-Pattern Scan Complete ==="
$fileSet = @($findings | ForEach-Object { $_.file } | Select-Object -Unique)
Write-Output "  Project is Flask: $projectIsFlask"
Write-Output "  Files scanned: $($fileSet.Count)"
Write-Output "  Lines scanned: $linesScanned"
Write-Output "  Total findings: $($findings.Count)"
$critical = @($findings | Where-Object { $_.severity -eq 'critical' }).Count
$high = @($findings | Where-Object { $_.severity -eq 'high' }).Count
$medium = @($findings | Where-Object { $_.severity -eq 'medium' }).Count
$low = @($findings | Where-Object { $_.severity -eq 'low' }).Count
Write-Output "  Critical: $critical | High: $high | Medium: $medium | Low: $low"

$result = @{
    projectIsFlask = $projectIsFlask
    findings = $findings
    counts = @{
        files = $fileSet.Count
        linesScanned = $linesScanned
        totalFindings = $findings.Count
        critical = $critical
        high = $high
        medium = $medium
        low = $low
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
