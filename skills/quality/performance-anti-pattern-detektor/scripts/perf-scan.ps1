[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ps1,*.py,*.js,*.ts,*.jsx,*.tsx,*.rb,*.php,*.java,*.go,*.cs,*.swift,*.kt,*.rs",

    [string]$Exclude = ""
)

# Path validation before ErrorActionPreference
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Host "ERROR: Path not found: $ProjectDir"
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
            foreach ($ex in $excludeList) { if ($f.FullName -like "*$ex*") { $skip = $true; break } }
            if (-not $skip -and $f.FullName -notlike "*\node_modules\*" -and $f.FullName -notlike "*\.git\*" -and $f.FullName -notlike "*\venv\*" -and $f.FullName -notlike "*\__pycache__\*" -and $f.FullName -notlike "*\.next\*" -and $f.FullName -notlike "*dist\*") {
                $files += $f
            }
        }
    }
    return $files
}

function Get-Context {
    param([string[]]$Lines, [int]$LineIndex, [int]$Radius = 3)
    $start = [Math]::Max(0, $lineIndex - $Radius)
    $end = [Math]::Min($Lines.Length - 1, $lineIndex + $Radius)
    $ctx = @()
    for ($i = $start; $i -le $end; $i++) { $ctx += $Lines[$i] }
    return ($ctx -join "`n")
}

function Is-InLoop {
    param([string[]]$Lines, [int]$LineIndex, [int]$Radius = 8)
    $start = [Math]::Max(0, $lineIndex - $Radius)
    $end = [Math]::Min($Lines.Length - 1, $lineIndex)
    for ($i = $start; $i -le $end; $i++) {
        $line = $Lines[$i]
        if ($line -match '(?i)\b(for|while|forEach|map|each|times|downto|upto|step)\b') { return $true }
    }
    return $false
}

function HasBatchLoad {
    param([string[]]$Lines, [int]$LineIndex, [int]$Radius = 10)
    $start = [Math]::Max(0, $lineIndex - $Radius)
    $end = [Math]::Min($Lines.Length - 1, $lineIndex + $Radius)
    $combined = ""
    for ($i = $start; $i -le $end; $i++) { $combined += $Lines[$i] + " " }
    return ($combined -match '(?i)(DataLoader|Include|ThenInclude|batch|eager|loadRelated|JOIN\s+.*ON|IN\s*\()')
}

function HasCleanup {
    param([string[]]$Lines, [int]$LineIndex, [int]$Radius = 15)
    $start = [Math]::Max(0, $lineIndex - $Radius)
    $end = [Math]::Min($Lines.Length - 1, $lineIndex + $Radius)
    $combined = ""
    for ($i = $start; $i -le $end; $i++) { $combined += $Lines[$i] + " " }
    return ($combined -match '(?i)(Dispose|dispose|cleanup|removeListener|off\s*\(|unsubscribe|destroy|RemoveHandler)')
}

$files = Get-SourceFiles -Dir $ProjectDir
$findings = @()
$findingId = 0
$seenKeys = @{}  # dedup: "file:line:pattern" → $true

foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($ProjectDir.Length).TrimStart('\')
    try {
        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $lines = $content -split "`n"
    } catch { continue }

    # 1. N+1 queries: DB query inside loop
    $matches = [regex]::Matches($content, '(?im)(\.query\s*\(|\.execute\s*\(|\.raw\s*\(|\.find\s*\(|\.findMany\s*\(|\.findAll\s*\(|SELECT\s+\*?\s+FROM)')
    foreach ($m in $matches) {
        $lineNum = ($content.Substring(0, $m.Index) -split "`n").Length
        $lineIndex = $lineNum - 1
        if (-not (Is-InLoop -Lines $lines -LineIndex $lineIndex)) { continue }
        if (HasBatchLoad -Lines $lines -LineIndex $lineIndex) { continue }
        $findingId++
        $evidLine = if ($lineIndex -lt $lines.Length) { $lines[$lineIndex].Trim() } else { "" }
        $findings += @{
            id = $findingId; pattern = "n-plus-one"; severity = "high"
            file = $relativePath; line = $lineNum
            evidence = $evidLine.Substring(0, [Math]::Min(200, $evidLine.Length))
            context = (Get-Context -Lines $lines -LineIndex $lineIndex)
            estimatedCallCount = "unbounded"
            suggestedFix = "Batch queries using JOIN, WHERE IN (...), or a DataLoader pattern."
        }
    }

    # 2. Sync-over-async: blocking calls in async contexts
    $syncMatches = [regex]::Matches($content, '(?im)(\.Result\b|\.Wait\s*\(|\.GetAwaiter\(\).*GetResult|Task\.Wait|Task\.Result|GetResult\s*\(\))')
    foreach ($m in $syncMatches) {
        $lineNum = ($content.Substring(0, $m.Index) -split "`n").Length
        $lineIndex = $lineNum - 1
        $patternName = "sync-over-async"
        $key = "${relativePath}:${lineNum}:${patternName}"
        if ($seenKeys.ContainsKey($key)) { continue }
        $seenKeys[$key] = $true
        $nearby = ($lines | Select-Object -Skip ([Math]::Max(0, $lineIndex - 3)) -First 6) -join ' '
        if ($nearby -notmatch '(?i)(async|await)') { continue }
        $findingId++
        $evidLine = if ($lineIndex -lt $lines.Length) { $lines[$lineIndex].Trim() } else { "" }
        $findings += @{
            id = $findingId; pattern = $patternName; severity = "high"
            file = $relativePath; line = $lineNum
            evidence = $evidLine.Substring(0, [Math]::Min(200, $evidLine.Length))
            context = (Get-Context -Lines $lines -LineIndex $lineIndex)
            estimatedCallCount = "per-invocation"
            suggestedFix = "Use async/await throughout instead of blocking on async calls."
        }
    }

    # 3. Hot-loop allocation: new object/array inside loop
    $matches = [regex]::Matches($content, '(?im)(new\s+\w+\s*\(|\[\s*\]|new\s+(Array|Object|Map|Set)\s*\(|{\s*})')
    foreach ($m in $matches) {
        $lineNum = ($content.Substring(0, $m.Index) -split "`n").Length
        $lineIndex = $lineNum - 1
        if (-not (Is-InLoop -Lines $lines -LineIndex $lineIndex)) { continue }
        $findingId++
        $evidLine = if ($lineIndex -lt $lines.Length) { $lines[$lineIndex].Trim() } else { "" }
        $findings += @{
            id = $findingId; pattern = "hot-loop-alloc"; severity = "medium"
            file = $relativePath; line = $lineNum
            evidence = $evidLine.Substring(0, [Math]::Min(200, $evidLine.Length))
            context = (Get-Context -Lines $lines -LineIndex $lineIndex)
            estimatedCallCount = "per-iteration"
            suggestedFix = "Hoist allocation outside the loop or reuse objects."
        }
    }

    # 4. Listener leak: addEventListener/on without matching remove
    $matches = [regex]::Matches($content, '(?im)((addEventListener|\.on\s*\(|subscribe\s*\(|connect\s*\(|addHandler)\s*[("''])')
    foreach ($m in $matches) {
        $lineNum = ($content.Substring(0, $m.Index) -split "`n").Length
        $lineIndex = $lineNum - 1
        if (HasCleanup -Lines $lines -LineIndex $lineIndex) { continue }
        $findingId++
        $evidLine = if ($lineIndex -lt $lines.Length) { $lines[$lineIndex].Trim() } else { "" }
        $findings += @{
            id = $findingId; pattern = "listener-leak"; severity = "medium"
            file = $relativePath; line = $lineNum
            evidence = $evidLine.Substring(0, [Math]::Min(200, $evidLine.Length))
            context = (Get-Context -Lines $lines -LineIndex $lineIndex)
            estimatedCallCount = "per-subscription"
            suggestedFix = "Store the listener reference and call removeEventListener/off/unsubscribe in cleanup."
        }
    }

    # 5. String concat in loop
    $matches = [regex]::Matches($content, '(?im)(\+=\s*["''`]|\.concat\s*\(|\.Append\s*\(|\.append\s*\()')
    foreach ($m in $matches) {
        $lineNum = ($content.Substring(0, $m.Index) -split "`n").Length
        $lineIndex = $lineNum - 1
        if (-not (Is-InLoop -Lines $lines -LineIndex $lineIndex)) { continue }
        $findingId++
        $evidLine = if ($lineIndex -lt $lines.Length) { $lines[$lineIndex].Trim() } else { "" }
        $findings += @{
            id = $findingId; pattern = "string-concat-loop"; severity = "low"
            file = $relativePath; line = $lineNum
            evidence = $evidLine.Substring(0, [Math]::Min(200, $evidLine.Length))
            context = (Get-Context -Lines $lines -LineIndex $lineIndex)
            estimatedCallCount = "per-iteration"
            suggestedFix = "Collect parts in an array and join() once, or use StringBuilder."
        }
    }

    # 6. Unnecessary serialization in loop
    $matches = [regex]::Matches($content, '(?im)(JSON\.stringify|JSON\.parse|JSON\.serialize|serialize|marshal)\s*\(')
    foreach ($m in $matches) {
        $lineNum = ($content.Substring(0, $m.Index) -split "`n").Length
        $lineIndex = $lineNum - 1
        if (-not (Is-InLoop -Lines $lines -LineIndex $lineIndex)) { continue }
        $findingId++
        $evidLine = if ($lineIndex -lt $lines.Length) { $lines[$lineIndex].Trim() } else { "" }
        $findings += @{
            id = $findingId; pattern = "unnecessary-serialization"; severity = "medium"
            file = $relativePath; line = $lineNum
            evidence = $evidLine.Substring(0, [Math]::Min(200, $evidLine.Length))
            context = (Get-Context -Lines $lines -LineIndex $lineIndex)
            estimatedCallCount = "per-iteration"
            suggestedFix = "Serialize once outside the loop or use a streaming format."
        }
    }

    # 7. Large closure capture (function returning function with large captured variable)
    $funcDefs = [regex]::Matches($content, '(?im)(function\s+\w+\s*\([^)]*\)\s*{[\s\S]*?(return\s+(function|\(?\s*\([^)]*\)\s*=>)))')
    foreach ($m in $funcDefs) {
        $lineNum = ($content.Substring(0, $m.Index) -split "`n").Length
        $lineIndex = $lineNum - 1
        # Check if captured variable is large (>300 chars of content)
        if ($m.Value.Length -gt 300 -and $m.Value -match '(?i)(var|let|const)\s+\w+\s*=\s*["''`{]') {
            $findingId++
            $evidLine = if ($lineIndex -lt $lines.Length) { $lines[$lineIndex].Trim() } else { "" }
            $findings += @{
                id = $findingId; pattern = "large-closure-capture"; severity = "medium"
                file = $relativePath; line = $lineNum
                evidence = $evidLine.Substring(0, [Math]::Min(200, $evidLine.Length))
                context = (Get-Context -Lines $lines -LineIndex $lineIndex)
                estimatedCallCount = "per-invocation"
                suggestedFix = "Pass large data as arguments instead of capturing in closure."
            }
        }
    }

    # 8. Redundant computation in loop
    $matches = [regex]::Matches($content, '(?im)(\.length\b|\.Count\b|\.size\b|\.count\b|Math\.\w+\s*\()')
    foreach ($m in $matches) {
        $lineNum = ($content.Substring(0, $m.Index) -split "`n").Length
        $lineIndex = $lineNum - 1
        if (-not (Is-InLoop -Lines $lines -LineIndex $lineIndex)) { continue }
        $findingId++
        $evidLine = if ($lineIndex -lt $lines.Length) { $lines[$lineIndex].Trim() } else { "" }
        # Only flag if it's property access inside loop condition (for i < arr.length)
        $before = $content.Substring([Math]::Max(0, $m.Index - 30), [Math]::Min(30, $m.Index))
        if ($before -match '(?i)(\bfor\s*\(|while\s*\(|do\s*\{)') {
            $findings += @{
                id = $findingId; pattern = "redundant-computation"; severity = "low"
                file = $relativePath; line = $lineNum
                evidence = ($lines[$lineIndex].Trim()).Substring(0, [Math]::Min(200, ($lines[$lineIndex].Trim()).Length))
                context = (Get-Context -Lines $lines -LineIndex $lineIndex)
                estimatedCallCount = "per-iteration"
                suggestedFix = "Cache .length/.Count in a variable before the loop."
            }
        }
    }
}

$stats = @{
    total = @($findings).Count
    bySeverity = @{
        high = @($findings | Where-Object { $_.severity -eq 'high' }).Count
        medium = @($findings | Where-Object { $_.severity -eq 'medium' }).Count
        low = @($findings | Where-Object { $_.severity -eq 'low' }).Count
    }
    byPattern = @{}
}
foreach ($f in $findings) {
    $p = $f.pattern
    if (-not $stats.byPattern.ContainsKey($p)) { $stats.byPattern[$p] = 0 }
    $stats.byPattern[$p]++
}

$output = @{
    findings = $findings
    counts = $stats
    summary = "Found $($stats.total) performance anti-pattern(s): $($stats.bySeverity.high) high, $($stats.bySeverity.medium) medium, $($stats.bySeverity.low) low."
}

$json = $output | ConvertTo-Json -Depth 5
Write-Output $json

Write-Output "=== Performance Anti-Pattern Scan Complete ==="
Write-Output "  Scanned: $($files.Count) files in $ProjectDir"
Write-Output "  Findings: $($stats.total) (high: $($stats.bySeverity.high), medium: $($stats.bySeverity.medium), low: $($stats.bySeverity.low))"
Write-Output "  By pattern:"
foreach ($p in $stats.byPattern.GetEnumerator() | Sort-Object Name) {
    Write-Output "    $($p.Key): $($p.Value)"
}
Write-Output ""
Write-Output "  Next step: run LLM analysis via SKILL.md steps 4-5"
