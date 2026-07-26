[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.cs,*.go,*.java,*.rb,*.php",
    [string]$Exclude = "",
    [int]$MaxBodyPreview = 600
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

# Symbol-name prefix classification (English-only; inexpensive regex set).
# getX/setX -> read/write by convention. isX/hasX/canX/shouldX -> boolean.
# Boundary: PascalCase char, non-word, or end of string -> recognizes getUser, getX,
# but rejects getx (continuation). \\b in PS 5.1 single-quoted strings is flaky,
# so use explicit character class.
$prefixRules = @(
    @{ prefix='^(get|read|fetch|load|find|search|query|list|enumerate|compute|calc|derive|obtain|peek|snapshot|describe)([A-Z]|\W|$)'; kind='reader' },
    @{ prefix='^(set|write|store|save|put|insert|delete|remove|update|add|push|append|register|publish|send|submit|clear|drop|reset|mark|close)([A-Z]|\W|$)'; kind='mutator' },
    @{ prefix='^(is|has|can|should|will|must|does|was|are|contains|equals|matches|exists|includes)([A-Z]|\W|$)'; kind='predicate' }
)

$asyncSuffixPattern = '(?:Async|Sync|Promise|Future|Task)([A-Z]|\W|$)'

# Mutations to detect within the body of a "reader" function.
# Boundary (\\b or (?!\\w)) handled implicitly; capturing either char class via (?<=[^\\w]|^) start when needed.
$mutationSignals = @(
    '^\s*global\.\w+\s*=',
    '^\s*self\.\w+\s*=',
    '^\s*this\.\w+\s*=',
    'INSERT\s+INTO',
    'UPDATE\s+\w+\s+SET',
    'DELETE\s+FROM',
    '\.save\s*\(',
    '\.create\s*\(',
    '\.insert\s*\(',
    '\.update\s*\(',
    '\.delete\s*\(',
    '\.destroy\s*\(',
    '\.push\s*\(',
    '\.pop\s*\(',
    '\.shift\s*\(',
    '\.unshift\s*\(',
    '\.splice\s*\(',
    '\.sort\s*\(',
    '\.reverse\s*\(',
    '\.fill\s*\(',
    '\.writeFile\s*\(',
    '\.write\s*\(',
    '\.appendFile\s*\(',
    'fs\.writeSync',
    'fs\.write',
    '\bdb\.commit\b',
    '\bconn\.commit\b',
    '\bcollection\.insert\b',
    '\bcollection\.update\b'
)

$ioSignals = @(
    'console\.log', 'console\.error', 'console\.warn',
    '\bprintln!', '\bprintf\(',
    'fetch\(', 'axios\.', '\brequests\.',
    'fs\.writeFile', 'fs\.appendFile',
    'mysql\.query', 'pg\.query', 'sqlite3\.',
    '\.save\('
)

$symbols = @()
$scannedFiles = 0

foreach ($ext in ($Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch 'node_modules|\.git|venv|bin|obj|__pycache__|dist|build'
    } | ForEach-Object {
        $fp = $_.FullName
        $scannedFiles++
        $content = Get-Content -LiteralPath $fp -Raw -ErrorAction SilentlyContinue
        if (-not $content) { return }
        $rel = $fp.Substring($ProjectDir.Length).TrimStart('\')
        $ext2 = [System.IO.Path]::GetExtension($fp).ToLower()
        $seenForFile = @{}

        # Match function/method declarations.
        $patterns = @(
            'function\s+(\w+)\s*\(',
            '(?:public|private|protected|static|export)?\s*(?:async\s+)?(\w+)\s*\([^)]*\)\s*[:\{]',
            'def\s+(\w+)\s*\(',
            'func\s+(\w+)\s*\('
        )

        foreach ($p in $patterns) {
            $r = [regex]::Matches($content, $p)
            foreach ($m in $r) {
                $name = $m.Groups[1].Value
                if (-not $name -or $name.StartsWith('_')) { continue }
                if ($name -in 'if','for','while','switch','return','function','class','else','do','case','default','try','catch','finally','require','import','from','export','const','let','var','new','throw','await','async','yield','render','constructor','get','set') { continue }
                $startIdx = $m.Index
                $lineNum = ($content.Substring(0, $startIdx) -split "`n").Count
                $dedupKey = "$lineNum|$name"
                if ($seenForFile.ContainsKey($dedupKey)) { continue }
                $seenForFile[$dedupKey] = $true
                $bodyStart = $content.IndexOf('{', $startIdx)
                if ($bodyStart -lt 0) { $bodyStart = $content.IndexOf(':', $startIdx) + 1 }
                if ($bodyStart -lt 0) { continue }

                # Brace-balanced body slice (capped at MaxBodyPreview).
                $depth = 0
                $bodyEnd = $bodyStart
                $foundEnd = $false
                $maxEnd = $bodyStart + $MaxBodyPreview
                if ($maxEnd -gt $content.Length) { $maxEnd = $content.Length }
                for ($j = $bodyStart; $j -lt $maxEnd; $j++) {
                    $ch = $content[$j]
                    if ($ch -eq '{') { $depth++ }
                    elseif ($ch -eq '}') {
                        $depth--
                        if ($depth -eq 0) { $bodyEnd = $j + 1; $foundEnd = $true; break }
                    }
                }
                $slice = $content.Substring($bodyStart, ($bodyEnd - $bodyStart))

                # Detect prefix kind.
                $kind = $null
                foreach ($rule in $prefixRules) {
                    if ($name -match $rule.prefix) { $kind = $rule.kind; break }
                }

                if (-not $kind) { continue }

                # Detect mutations.
                $mutationHits = @()
                foreach ($ms in $mutationSignals) {
                    if ($slice -match $ms) { $mutationHits += $ms }
                }
                $ioHits = @()
                foreach ($ios in $ioSignals) {
                    if ($slice -match $ios) { $ioHits += $ios }
                }

                # Async detection (heuristic).
                $isAsync = $content.Substring([Math]::Max(0, $startIdx - 30), [Math]::Min(40, $m.Index - [Math]::Max(0, $startIdx-30) + 30)) -match 'async\s*$|Promise'
                $hasAsyncSuffix = $name -match $asyncSuffixPattern

                $symbols += @{
                    file = $rel
                    line = $lineNum
                    name = $name
                    prefixKind = $kind
                    mutations = $mutationHits
                    ios = $ioHits
                    isAsync = $isAsync
                    hasAsyncSuffix = $hasAsyncSuffix
                    bodyPreview = $slice.Substring(0, [Math]::Min($MaxBodyPreview, $slice.Length))
                }
            }
        }
    }
}

$result = @{
    symbols = $symbols
    counts = @{
        scannedFiles = $scannedFiles
        totalSymbols = $symbols.Count
        readers = @($symbols | Where-Object { $_.prefixKind -eq 'reader' }).Count
        mutators = @($symbols | Where-Object { $_.prefixKind -eq 'mutator' }).Count
        predicates = @($symbols | Where-Object { $_.prefixKind -eq 'predicate' }).Count
        readerWithMutations = @($symbols | Where-Object { $_.prefixKind -eq 'reader' -and $_.mutations.Count -gt 0 }).Count
    }
}

Write-Output "=== Name-Harvest Scan Complete ==="
Write-Output "  Files scanned: $scannedFiles"
Write-Output "  Symbol candidates: $($symbols.Count)"
Write-Output "  Readers (getX): $($result.counts.readers)"
Write-Output "  Mutators (setX): $($result.counts.mutators)"
Write-Output "  Predicates (isX): $($result.counts.predicates)"
Write-Output "  Readers with mutations (suspicious): $($result.counts.readerWithMutations)"

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
