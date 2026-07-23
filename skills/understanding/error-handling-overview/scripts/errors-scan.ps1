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

# All catch-site patterns by language
$catchPatterns = @(
    # JS/TS/Java/C#: try { ... } catch(e) { ... }
    @{ regex='catch\s*\(\s*\w+\s*\)\s*\{'; lang='js-like' },
    # JS/TS: .catch(function(err) ... ) or .catch(err => ... )
    @{ regex='\.\s*catch\s*\(\s*(?:function\s*)?\(\s*\w+\s*\)'; lang='js-promise' },
    @{ regex='\.\s*catch\s*\(\s*\w+\s*=>'; lang='js-promise' },
    # Python: except <Type> as e:
    @{ regex='except\s+(?:\w+\s*(?:as\s+\w+)?)?\s*:'; lang='python' },
    # Go: defer func() { if r := recover(); r != nil { ... } }()
    @{ regex='recover\s*\(\s*\)'; lang='go' },
    # Ruby: rescue => e / rescue Exception => e
    @{ regex='rescue\s+(?:\w+\s*)?=>?\s*\w*'; lang='ruby' }
)

# Catch-block classification: read the next N lines to determine type
$catchTypePatterns = @(
    @{ regex='console\.error|logger\.error|log\.error|log\.err|Write-Error|print\s*\(\s*e|print\s*\(\s*err|sys\.stderr'; type='log' },
    @{ regex='throw\s+\w|throw\s+new|raise\s+|throw e|throw err'; type='rethrow' },
    @{ regex='fallback|default\s*[:=]|alternative|return\s+default|return\s+fallback|\|\||\?\?|circuitBreaker'; type='fallback' },
    @{ regex='retry|backoff|attempt|maxRetries|retryCount|sleep\s*\('; type='recover' }
)

# Global error handlers (language/framework specific)
$globalHandlerPatterns = @(
    @{ regex='app\.use\s*\(\s*function\s*\(\s*err\s*,\s*req\s*,\s*res\s*,\s*next\s*\)'; kind='express-middleware' },
    @{ regex='process\.on\s*\(\s*[\x27"]uncaughtException[\x27"]\s*,'; kind='node-uncaught' },
    @{ regex='process\.on\s*\(\s*[\x27"]unhandledRejection[\x27"]\s*,'; kind='node-unhandled' },
    @{ regex='@ControllerAdvice'; kind='spring-advice' },
    @{ regex='@ExceptionHandler'; kind='spring-handler' },
    @{ regex='@app\.errorhandler'; kind='flask-handler' },
    @{ regex='sys\.excepthook\s*='; kind='python-hook' },
    @{ regex='app\.use\s*\(\s*\(\s*err\s*,\s*req\s*,\s*res\s*,\s*next\s*\)'; kind='express-arrow' }
)

# Custom error class patterns
$errorClassPatterns = @(
    @{ regex='class\s+(\w+Error)\s+extends\s+(\w+)'; kind='extends-error' },
    @{ regex='class\s+(\w+Exception)\s+extends\s+(\w+)'; kind='extends-exception' },
    @{ regex='class\s+(\w+Error)'; kind='error-class' },
    @{ regex='class\s+(\w+Exception)'; kind='exception-class' },
    @{ regex='class\s+(\w+Error)\s+implements\s+\w+Exception'; kind='implements-exception' },
    @{ regex='class\s+(\w+Exception)\s+:\s+\w+Exception'; kind='csharp-exception' },
    @{ regex='class\s+(\w+Error)\s+:\s+Exception'; kind='csharp-error' }
)

$handlers = @()
$globalHandlers = @()
$errorHierarchy = @()
$hierarchyEdges = @()  # { child, parent }
$linesScanned = 0

function Get-IndentLevel($line) {
    $sp = 0
    foreach ($ch in $line.ToCharArray()) {
        if ($ch -eq ' ' -or $ch -eq "`t") { $sp++ } else { break }
    }
    return $sp
}

function Classify-CatchBlock($lines, $startLine, $braceOpenLine) {
    # Read from braceOpenLine forward until we find the matching close brace
    # Depth-based brace matching
    $depth = 0
    $inBrace = $false
    $catchLines = @()
    for ($i = $braceOpenLine; $i -lt $lines.Count; $i++) {
        $ln = $lines[$i]
        $catchLines += $ln
        foreach ($ch in $ln.ToCharArray()) {
            if ($ch -eq '{') { $depth++; $inBrace = $true }
            if ($ch -eq '}') { $depth-- }
        }
        if ($inBrace -and $depth -le 0) { break }
    }

    $body = ($catchLines -join "`n")

    # Empty catch: just opening and closing brace with optional whitespace/comments
    $stripped = ($catchLines | ForEach-Object { $_ -replace '//.*', '' -replace '#.*', '' -replace '/\*.*?\*/', '' } | Where-Object { $_.Trim() -ne '' })
    if ($stripped.Count -le 1) {
        return 'swallow'
    }

    # Classify by priority: rethrow > recover > fallback > log > swallow
    if ($body -match 'throw\s+\w|throw\s+new|raise\s+|throw e|throw err') { return 'rethrow' }
    if ($body -match 'retry|backoff|attempt|maxRetries|retryCount|sleep\s*\(') { return 'recover' }
    if ($body -match 'fallback|default\s*[:=]|alternative|return\s+default|return\s+fallback|\|\||\?\?|circuitBreaker') { return 'fallback' }
    if ($body -match 'console\.error|logger\.error|log\.error|log\.err|Write-Error|print\s*\(\s*e|print\s*\(\s*err|sys\.stderr') { return 'log' }

    # Has code but no recognizable pattern
    return 'swallow'
}

function Get-CatchTypeFromLine($ln, $nextLines) {
    $context = $ln + "`n" + ($nextLines -join "`n")
    if ($context -match 'throw\s+\w|throw\s+new|raise\s+|throw e|throw err') { return 'rethrow' }
    if ($context -match 'retry|backoff|attempt|maxRetries|retryCount|sleep\s*\(') { return 'recover' }
    if ($context -match 'fallback|default\s*[:=]|alternative|return\s+default|return\s+fallback|\|\||\?\?|circuitBreaker') { return 'fallback' }
    if ($context -match 'console\.error|logger\.error|log\.error|log\.err|Write-Error|print\s*\(\s*e|print\s*\(\s*err|sys\.stderr') { return 'log' }
    return 'swallow'
}

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

            # ---- 1. Detect global error handlers ----
            foreach ($r in $globalHandlerPatterns) {
                if ($ln -match $r.regex) {
                    $globalHandlers += @{
                        file = $rel
                        line = $li + 1
                        kind = $r.kind
                        lineContent = ($ln.Trim() -replace '\s+', ' ')
                    }
                }
            }

            # ---- 2. Detect custom error classes ----
            foreach ($r in $errorClassPatterns) {
                $m = [regex]::Match($ln, $r.regex)
                if ($m.Success) {
                    $className = $m.Groups[1].Value
                    $parentClass = if ($m.Groups.Count -gt 2) { $m.Groups[2].Value } else { $null }
                    $entry = @{
                        file = $rel
                        line = $li + 1
                        className = $className
                        kind = $r.kind
                        lineContent = ($ln.Trim() -replace '\s+', ' ')
                    }
                    if ($parentClass) { $entry.parentClass = $parentClass }
                    $errorHierarchy += $entry
                    if ($parentClass) {
                        $hierarchyEdges += @{ child = $className; parent = $parentClass }
                    }
                }
            }

            # ---- 3. Detect catch blocks ----
            foreach ($r in $catchPatterns) {
                if ($ln -match $r.regex) {
                    # Determine catch type by looking at surrounding lines
                    # Collect lines until next catch or end of block
                    $endIdx = [Math]::Min($li + 15, $lines.Count - 1)
                    $nextLines = $lines[($li + 1)..$endIdx]
                    $catchType = Get-CatchTypeFromLine $ln $nextLines

                    # For try/catch with braces: find the opening brace
                    $braceLine = $li
                    for ($j = $li; $j -lt $lines.Count; $j++) {
                        if ($lines[$j] -match '\{') { $braceLine = $j; break }
                    }
                    if ($braceLine -gt $li) {
                        $lookahead = $lines[$braceLine..[Math]::Min($braceLine + 20, $lines.Count - 1)]
                        $catchType2 = Classify-CatchBlock $lines $li $braceLine
                        if ($catchType2 -ne 'swallow' -or $catchType -eq 'swallow') {
                            # Prefer the deeper analysis
                        }
                        # Use the deeper classifier when available
                        $classifyLines = $lines[$braceLine..[Math]::Min($braceLine + 30, $lines.Count - 1)]
                        $catchType = Classify-CatchBlock $lines $li $braceLine
                    }

                    # For .catch() without braces: look for => or function body
                    if ($ln -match '\.\s*catch') {
                        if ($ln -match '=>\s*\{') {
                            $braceIdx = $ln.IndexOf('{')
                            $classifyLines = $lines[$li..[Math]::Min($li + 10, $lines.Count - 1)]
                            $catchType = Classify-CatchBlock $lines $li $li
                        } elseif ($ln -match '=>\s+\w') {
                            # Single expression arrow: .catch(e => fallback)
                            $catchType = Get-CatchTypeFromLine $ln @()
                        }
                    }

                    $handlers += @{
                        file = $rel
                        line = $li + 1
                        lang = $r.lang
                        catchType = $catchType
                        lineContent = ($ln.Trim() -replace '\s+', ' ')
                    }
                }
            }
        }
    }
}

# Build error hierarchy tree from edges
$hierarchyRoots = @()
$allChildren = @{}
foreach ($e in $hierarchyEdges) {
    if (-not $allChildren.ContainsKey($e.parent)) { $allChildren[$e.parent] = @() }
    $allChildren[$e.parent] += $e.child
}
$allParents = @{}
foreach ($e in $hierarchyEdges) {
    $allParents[$e.child] = $e.parent
}
$allNodes = @{}
foreach ($e in $hierarchyEdges) {
    $allNodes[$e.child] = $true
    $allNodes[$e.parent] = $true
}
$roots = @()
foreach ($n in $allNodes.Keys) {
    if (-not $allParents.ContainsKey($n)) { $roots += $n }
}

# Count by type
$countByType = @{}
$countByLang = @{}
foreach ($h in $handlers) {
    $t = $h.catchType
    if (-not $countByType.ContainsKey($t)) { $countByType[$t] = 0 }
    $countByType[$t]++
    $l = $h.lang
    if (-not $countByLang.ContainsKey($l)) { $countByLang[$l] = 0 }
    $countByLang[$l]++
}

$fileSet = @($handlers | ForEach-Object { $_.file } | Select-Object -Unique)

Write-Output "=== Error Handling Overview Complete ==="
Write-Output "  Files scanned: $($fileSet.Count)"
Write-Output "  Lines scanned: $linesScanned"
Write-Output "  Total catch sites: $($handlers.Count)"
$countByType.Keys | Sort-Object | ForEach-Object { Write-Output "    $_`: $($countByType[$_])" }
Write-Output "  Global error handlers: $($globalHandlers.Count)"
Write-Output "  Custom error classes: $($errorHierarchy.Count)"
if ($roots.Count -gt 0) { Write-Output "  Error hierarchy roots: $($roots -join ', ')" }

$result = @{
    handlers = $handlers
    globalHandlers = $globalHandlers
    errorHierarchy = $errorHierarchy
    hierarchyEdges = $hierarchyEdges
    counts = @{
        filesWithHandlers = $fileSet.Count
        linesScanned = $linesScanned
        totalCatchSites = $handlers.Count
        byCatchType = $countByType
        byLang = $countByLang
        globalHandlers = $globalHandlers.Count
        customErrorClasses = $errorHierarchy.Count
        hierarchyRoots = $roots
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
