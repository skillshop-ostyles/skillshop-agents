[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.cs,*.go,*.java,*.rb,*.php",

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

# --------------------------------------------------------------------
# INPUT SOURCE patterns
# --------------------------------------------------------------------
$inputPatterns = @(
    # HTTP route decorators / handlers
    @{ regex='@(?:Post|Get|Put|Patch|Delete)\s*\(\s*[''"]';      type='http-decorator' }
    @{ regex='app\.\s*(?:post|get|put|patch|delete)\s*\(';        type='express-route' }
    @{ regex='@app\.route\s*\(';                                   type='flask-route' }
    @{ regex='router\.\s*(?:post|get|put|patch|delete)\s*\(';     type='express-router' }
    @{ regex='\.\s*post\s*\(\s*[''"]';                             type='generic-post' }
    # Event handlers
    @{ regex='\.\s*on\s*\(\s*[''"]\w+[''"]';                      type='event-handler' }
    @{ regex='@EventListener\b';                                   type='spring-event' }
    @{ regex='@KafkaListener\b';                                   type='kafka-listener' }
    @{ regex='\.\s*subscribe\s*\(';                                type='observable' }
    # File reads
    @{ regex='\bfs\.\s*readFile\s*\(';                             type='file-read' }
    @{ regex='\breadFileSync\s*\(';                                type='file-read' }
    @{ regex='\.\s*read\s*\(\s*\)';                                type='stream-read' }
    @{ regex='open\s*\([^)]*\)\s*\.\s*read\b';                    type='file-read' }
    @{ regex='\bread\s*\(';                                        type='stream-read' }
    # Body / input access
    @{ regex='req\.\s*body';                                       type='request-body' }
    @{ regex='request\.\s*body';                                   type='request-body' }
    @{ regex='event\.\s*body';                                     type='event-body' }
    @{ regex='context\.\s*args';                                   type='function-arg' }
    @{ regex='sys\.\s*stdin';                                      type='stdin' }
)

# --------------------------------------------------------------------
# SINK patterns
# --------------------------------------------------------------------
$sinkPatterns = @(
    # DB calls
    @{ regex='\.\s*find\s*\(';                                    type='db-read' }
    @{ regex='\.\s*create\s*\(';                                   type='db-write' }
    @{ regex='\.\s*save\s*\(';                                     type='db-write' }
    @{ regex='\.\s*updateOne\s*\(';                                type='db-write' }
    @{ regex='\.\s*updateMany\s*\(';                               type='db-write' }
    @{ regex='\.\s*delete\s*\(';                                   type='db-write' }
    @{ regex='\.\s*findMany\s*\(';                                 type='db-read' }
    @{ regex='\.\s*findFirst\s*\(';                                type='db-read' }
    @{ regex='\bpool\.\s*query\s*\(';                              type='db-query' }
    @{ regex='\bprisma\.\s*\w+\s*\.\s*(?:create|update|delete|find|upsert)'; type='prisma' }
    @{ regex='\bdb\.\s*\w+\s*\.\s*(?:create|update|delete|find)'; type='db-query' }
    @{ regex='\bquery\s*\(';                                       type='db-query' }
    # HTTP outbound
    @{ regex='\bfetch\s*\(';                                       type='http-out' }
    @{ regex='\baxios\s*\.\s*(?:get|post|put|patch|delete|request)\s*\('; type='http-out' }
    @{ regex='\bgot\s*\(';                                         type='http-out' }
    @{ regex='\brequests\s*\.\s*(?:get|post|put|patch|delete)\s*\('; type='http-out' }
    # File writes
    @{ regex='\bfs\.\s*writeFile\s*\(';                            type='file-write' }
    @{ regex='\bwriteFileSync\s*\(';                               type='file-write' }
    @{ regex='\.\s*write\s*\(\s*\)';                               type='file-write' }
    # Logs
    @{ regex='\bconsole\.\s*log\s*\(';                             type='log' }
    @{ regex='\blogger\.\s*(?:info|warn|error|debug)\s*\(';        type='log' }
    @{ regex='\blog\.\s*(?:info|warn|error|debug)\s*\(';           type='log' }
    @{ regex='\bLog\.\s*(?:Information|Warning|Error|Debug)\s*\('; type='log' }
)

# --------------------------------------------------------------------
# SCAN: Collect all input sources and sinks per file
# --------------------------------------------------------------------
$flows = @()
$allSources = @()  # {file, line, type, code, vars}

function Get-RelativePath($base, $target) {
    $base = $base.TrimEnd('\').TrimEnd('/')
    $tp = $target.TrimEnd('\').TrimEnd('/')
    if ($tp -eq $base) { return '.' }
    if ($tp.StartsWith($base + '\') -or $tp.StartsWith($base + '/')) {
        return $tp.Substring($base.Length + 1)
    }
    return $tp
}

function Get-VariablesInLine($line) {
    $vars = @()
    # Match assignment targets: let/const/var x = ..., x = ..., destructuring
    if ($line -match '(?:let|const|var)\s+(\w[\w.]*)\s*=') { $vars += $matches[1] }
    if ($line -match '(?:let|const|var)\s+\{\s*([\w,\s]+)\s*}\s*=') {
        $matches[1] -split ',' | ForEach-Object { $v = $_.Trim(); if ($v) { $vars += $v } }
    }
    # Also capture any variable on the left of =
    if ($line -match '^\s*(\w[\w.]*)\s*=(?!=)') { $vars += $matches[1] }
    return $vars | Select-Object -Unique
}

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
        $rel = Get-RelativePath $ProjectDir $fn
        $lines = $content -split "`n"
        $linesScanned += $lines.Count

        # -- Phase 1: Find all input sources in this file --
        for ($li = 0; $li -lt $lines.Count; $li++) {
            $ln = $lines[$li]
            if ($ln -match '^\s*[/#*]') { continue }

            foreach ($ip in $inputPatterns) {
                if ($ln -match $ip.regex) {
                    # Determine the primary variable receiving input data
                    $inputVars = @(Get-VariablesInLine $ln)
                    # Also capture req.body/req.query property accesses as implicit sources
                    if ($ln -match 'req\.\s*(body|query|params)') { $inputVars = @($inputVars) + "req.$($matches[1])" }
                    if ($ln -match 'event\.\s*body') { $inputVars = @($inputVars) + "event.body" }
                    if ($inputVars.Count -eq 0) { $inputVars = @($inputVars) + "input" }

                    $allSources += @{
                        file = $rel
                        line = $li + 1
                        type = $ip.type
                        code = $ln.Trim()
                        vars = $inputVars
                    }
                    break
                }
            }
        }
    }
}

# -- Phase 2: For each source, trace forward to sinks --
# Walk through all files again, this time finding sinks and trying to
# connect them to source variables via assignment tracing.

$allFiles = @()
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
        $rel = Get-RelativePath $ProjectDir $fn
        $lines = $content -split "`n"
        $allFiles += @{ rel = $rel; lines = $lines; file = $fn }
    }
}

# For each source, try to trace to sinks
# Strategy: for each input source variable, search every file for sink calls
# on lines that reference the variable. Follow variable assignments up to 3 hops.
$MAX_TRACE_ITERS = 2000
$totalTraceIters = 0

foreach ($src in $allSources) {
    $sourceVars = $src.vars
    $sourceFile = $src.file

    $tracedSinks = @()
    $traceSeen = @{}

    # Seed: for each source var, scan all files for sink proximity
    $scanVars = @($sourceVars | Where-Object { $_ -and -not $traceSeen.ContainsKey($_) })
    foreach ($sv in $scanVars) { $traceSeen[$sv] = 0 }

    for ($hop = 0; $hop -le 3; $hop++) {
        if ($totalTraceIters -ge $MAX_TRACE_ITERS) { break }
        $nextVars = @{}

        foreach ($fa in $allFiles) {
            if ($totalTraceIters -ge $MAX_TRACE_ITERS) { break }
            $farel = $fa.rel
            for ($li = 0; $li -lt $fa.lines.Count; $li++) {
                $totalTraceIters++
                if ($totalTraceIters -ge $MAX_TRACE_ITERS) { break }
                $ln = $fa.lines[$li]
                if ($ln -match '^\s*[/#*]') { continue }

                # Check if line references any source variable (substring match)
                $matchedVarName = $null
                foreach ($sv in $scanVars) {
                    if ($sv -and $ln -match [regex]::Escape($sv)) { $matchedVarName = $sv; break }
                }
                if (-not $matchedVarName) { continue }

                # Check if this line is a sink call
                foreach ($sp in $sinkPatterns) {
                    if ($ln -match $sp.regex) {
                        $ctxStart = [Math]::Max(0, $li - 5)
                        $ctxEnd = [Math]::Min($fa.lines.Count - 1, $li + 5)
                        $ctxWindow = ($fa.lines[$ctxStart..$ctxEnd] -join ' ')
                        $hasValidation = $ctxWindow -match '\bif\b|\btypeof\b|\bvalidate\b|\bzod\b|\bjoi\b|\byup\b|\bclass-validator\b'

                        $tracedSinks += @{
                            sinkFile = $farel
                            sinkLine = $li + 1
                            sinkType = $sp.type
                            sourceVar = $matchedVarName
                            hopCount = $hop + 1
                            hasValidation = $hasValidation
                            code = $ln.Trim()
                        }
                        break
                    }
                }

                # Track assignment to continue chain: find LHS variables
                if ($hop -lt 3) {
                    $assignedVars = Get-VariablesInLine $ln
                    foreach ($av in $assignedVars) {
                        if ($av -and -not $traceSeen.ContainsKey($av)) {
                            $nextVars[$av] = $true
                        }
                    }
                }
            }
        }

        $scanVars = @($nextVars.Keys)
        foreach ($nv in $scanVars) { $traceSeen[$nv] = $hop + 1 }
    }

    if ($tracedSinks.Count -gt 0) {
        $flows += @{
            inputFile = $src.file
            inputLine = $src.line
            sourceType = $src.type
            inputCode = $src.code
            sinks = $tracedSinks
        }
    }
}

# --------------------------------------------------------------------
# REPORT
# --------------------------------------------------------------------
$flowCount = $flows.Count
$sinkCount = @($flows | ForEach-Object { $_.sinks }).Count
$validatedFlows = @($flows | Where-Object {
    $hasV = $false
    foreach ($s in $_.sinks) { if ($s.hasValidation) { $hasV = $true; break } }
    $hasV
}).Count

Write-Output "=== Data Flow Scan Complete ==="
Write-Output "  Lines scanned: $linesScanned"
Write-Output "  Input sources found: $($allSources.Count)"
Write-Output "  Data flows traced: $flowCount"
Write-Output "  Sink hops detected: $sinkCount"
Write-Output "  Flows with validation: $validatedFlows"

$result = @{
    flows = $flows
    sources = $allSources
    counts = @{
        linesScanned = $linesScanned
        totalSources = $allSources.Count
        totalFlows = $flowCount
        totalSinks = $sinkCount
        validatedFlows = $validatedFlows
    }
}

Write-Output ($result | ConvertTo-Json -Depth 10)
exit 0
