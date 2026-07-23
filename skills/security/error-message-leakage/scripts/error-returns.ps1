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

# Patterns that return error info to callers. Each tagged with what kind of
# info it likely leaks so the LLM can classify without re-reading the line.
$leakagePatterns = @(
    @{ regex='res\.(?:send|json|status)\s*\(\s*err\.stack\b'; kind='stacktrace' },
    @{ regex='res\.(?:send|json)\s*\(\s*err\b'; kind='error-object' },
    @{ regex='res\.(?:send|json)\s*\(\s*\{[^}]*error\s*:\s*err\b'; kind='error-object' },
    @{ regex='throw\s+new\s+Error\s*\(\s*JSON\.stringify\s*\('; kind='json-stringified-error' },
    @{ regex='res\.(?:send|json)\s*\(\s*req\.body\b'; kind='echo-user-input' },
    @{ regex='res\.(?:send|json|status)\s*\(\s*process\.env\b'; kind='env-vars' },
    @{ regex='res\.(?:send|json)\s*\(\s*\.{1,2}\??\/?[A-Za-z_]+\b[^)]*error'; kind='error-message-text' },
    @{ regex='res\.(?:send|json)\s*\(\s*\{[^}]*stack\s*:'; kind='stacktrace-object' },
    @{ regex='res\.(?:send|response)\.(?:send)\s*\('; kind='response-send' },
    @{ regex='return\s+res\.status\s*\(\s*\d{3}\s*\)\.send\s*\(\s*err\b'; kind='stacktrace' },
    @{ regex='return\s+(?:new\s+)?(?:Response|JsonResponse)\s*\([^)]*err\b'; kind='error-object' }
)

# Server-log calls that ALSO leak (logger writes to disk; forensic-attacker reads).
$logLeakPatterns = @(
    @{ regex='console\.error\s*\(\s*err\.stack\b'; kind='stacktrace' },
    @{ regex='console\.error\s*\(\s*err\b'; kind='error-object' },
    @{ regex='console\.log\s*\(\s*(?:req|request)\.'; kind='request-dump' },
    @{ regex='logger\.error\s*\(\s*err\.stack\b'; kind='stacktrace' },
    @{ regex='console\.log\s*\(\s*process\.env\b'; kind='env-vars' }
)

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
            foreach ($r in $leakagePatterns) {
                if ($ln -match $r.regex) {
                    $findings += @{
                        file = $rel
                        line = $li + 1
                        leakKind = $r.kind
                        surface = 'http-response'
                        lineContent = ($ln.Trim() -replace '\s+', ' ')
                    }
                }
            }
            foreach ($r in $logLeakPatterns) {
                if ($ln -match $r.regex) {
                    $findings += @{
                        file = $rel
                        line = $li + 1
                        leakKind = $r.kind
                        surface = 'log-statement'
                        lineContent = ($ln.Trim() -replace '\s+', ' ')
                    }
                }
            }
        }
    }
}

Write-Output "=== Error-Leakage Scan Complete ==="
$fileSet = @($findings | ForEach-Object { $_.file } | Select-Object -Unique)
Write-Output "  Files: $($fileSet.Count)"
Write-Output "  Lines scanned: $linesScanned"
Write-Output "  Findings: $($findings.Count)"
Write-Output "  http-response leaks: $(@($findings | Where-Object { $_.surface -eq 'http-response' }).Count)"
Write-Output "  log-statement leaks: $(@($findings | Where-Object { $_.surface -eq 'log-statement' }).Count)"

$result = @{
    findings = $findings
    counts = @{
        files = $fileSet.Count
        totalFindings = $findings.Count
        httpResponseLeaks = (@($findings | Where-Object { $_.surface -eq 'http-response' }).Count)
        logStatementLeaks = (@($findings | Where-Object { $_.surface -eq 'log-statement' }).Count)
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
