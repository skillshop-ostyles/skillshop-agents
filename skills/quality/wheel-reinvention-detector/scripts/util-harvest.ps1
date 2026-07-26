[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.cs,*.go,*.java,*.rb,*.php",
    [string]$Exclude = "",

    # Heuristics for "candidate utility function": small, no class state, exported,
    # or named like a helper. We extract functions under 40 lines.
    [int]$MaxBodyLines = 40,
    [int]$MaxBodyChars = 2000
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

# Detect installed libraries to surface as candidates for replacement.
$installedLibs = @()
$inferredStdlib = @{
    'ts' = @('Array', 'Map', 'Set', 'Object', 'Promise', 'Math', 'JSON', 'Number', 'String', 'Boolean')
    'tsx' = @('Array', 'Map', 'Set', 'Object', 'Promise', 'Math', 'JSON', 'Number', 'String', 'Boolean', 'React')
    'js' = @('Array', 'Map', 'Set', 'Object', 'Promise', 'Math', 'JSON', 'Number', 'String', 'Boolean')
    'jsx' = @('Array', 'Map', 'Set', 'Object', 'Promise', 'Math', 'JSON', 'Number', 'String', 'Boolean', 'React')
    'py' = @('itertools', 'functools', 'collections', 'pathlib', 'os.path', 're', 'json', 'math', 'datetime')
    'cs' = @('System.Linq', 'System.Collections.Generic', 'System.IO.Path', 'System.Text.Json', 'System.Threading.Tasks')
    'go' = @('sort', 'strings', 'sync', 'context', 'encoding/json', 'io', 'os', 'time', 'net/http', 'path/filepath')
    'java' = @('java.util', 'java.util.stream', 'java.util.Collections', 'java.util.Arrays', 'java.io', 'java.nio.file')
    'rb' = @('Enumerable', 'Array', 'Hash', 'File', 'Pathname', 'JSON', 'Time')
    'php' = @('array_', 'str_', 'Spl', 'Iterator', 'DateTime')
}

# Read installed packages.
$packageJson = Join-Path $ProjectDir 'package.json'
if (Test-Path -LiteralPath $packageJson) {
    $pj = Get-Content -LiteralPath $packageJson -Raw | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($pj.dependencies) {
        foreach ($p in $pj.dependencies.PSObject.Properties) {
            $installedLibs += $p.Name
        }
    }
    if ($pj.devDependencies) {
        foreach ($p in $pj.devDependencies.PSObject.Properties) {
            $installedLibs += $p.Name
        }
    }
}
$requirementsTxt = Join-Path $ProjectDir 'requirements.txt'
if (Test-Path -LiteralPath $requirementsTxt) {
    $lines = Get-Content -LiteralPath $requirementsTxt -ErrorAction SilentlyContinue
    foreach ($l in $lines) {
        if ($l -match '^([A-Za-z0-9_.-]+)') {
            $installedLibs += $matches[1]
        }
    }
}

# Extract candidate utility functions.
function Get-UtilCandidates($content) {
    $candidates = @()
    $lines = $content -split "`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '^\s*(export\s+)?(async\s+)?function\s+(\w+)([^()]*)\(') {
            $name = $matches[3]
            # Brace-balanced body.
            $depth = 0; $end = $i; $seenBrace = $false; $endReached = $false
            for ($j = $i; $j -lt $lines.Count -and -not $endReached; $j++) {
                foreach ($c in $lines[$j].ToCharArray()) {
                    if ($c -eq '{') { $depth++; $seenBrace = $true }
                    elseif ($c -eq '}') {
                        $depth--
                        if ($seenBrace -and $depth -eq 0) { $end = $j; $endReached = $true; break }
                    }
                }
            }
            $body = ($lines[$i..$end] -join "`n")
            if (($end - $i) -le 40) {
                $candidates += @{
                    name = $name
                    body = $body
                    lineCount = $end - $i
                    snippet = $body
                }
            }
        }
    }
    return ,$candidates
}

$utilCandidates = @()
foreach ($ext in ($Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    $items = Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue
    $kept = @()
    foreach ($i in $items) {
        $fn = $i.FullName
        $accept = $true
        if ($fn -match '[\\/]node_modules[\\/]|[\\/]\.git[\\/]|[\\/]venv[\\/]|[\\/]__pycache__[\\/]|[\\/]dist[\\/]|[\\/]build[\\/]|[\\/]bin[\\/]|[\\/]obj[\\/]') { $accept = $false }
        if ($accept -and ($fn -match '\.test\.|\.spec\.|_test\.py|Test\.cs')) { $accept = $false }
        if ($accept -and ($fn -match '[\\/]fixtures[\\/]')) { $accept = $true }
        if ($accept -and ($fn -match '[\\/]tests[\\/]fixtures[\\/]')) { $accept = $true }
        if ($accept -and ($fn -match '[\\/]tests[\\/]') -and ($fn -notmatch '[\\/]fixtures[\\/]')) { $accept = $false }
        if ($accept) { $kept += $i }
    }
    $kept | ForEach-Object {
        $fp = $_.FullName
        $content = Get-Content -LiteralPath $fp -Raw -ErrorAction SilentlyContinue
        if (-not $content) { return }
        $rel = $fp.Substring($ProjectDir.Length).TrimStart('\')
        $candidates = Get-UtilCandidates $content
        foreach ($c in $candidates) {
            $c.file = $rel
            $c.startLine = 1
            $utilCandidates += $c
        }
    }
}

# Quick semantic hints to help LLM (its job is to map to stdlib + lib equivalents).
$semanticHints = @{
    'group' = 'groupBy / groupBy / Array.from grouped iter / itertools.groupby'
    'chunk' = 'chunked / chunk / SQL chunk size / _.chunk'
    'flatten' = 'Array.prototype.flat / lodash.flattenDeep / itertools.chain.from_iterable'
    'uniq' = '[...new Set(...)] / lodash.uniq / list(dict.fromkeys(items))'
    'retry' = 'p-retry / tenacity / retry decorator'
    'throttle' = 'lodash.throttle / RxJS throttleTime'
    'debounce' = 'lodash.debounce / RxJS debounceTime'
    'sleep' = 'setTimeout/await/Promise + setTimeout / asyncio.sleep / time.Sleep'
    'sleepMs' = 'setTimeout / asyncio.sleep'
    'sleepSeconds' = 'time.Sleep / asyncio.sleep'
    'pick' = 'lodash.pick / structuredClone filter / { pick(obj, keys) }'
    'omit' = 'lodash.omit'
    'merge' = 'lodash.merge / Object.assign with deep option'
}

Write-Output "=== Wheel-Reinvention Scan Complete ==="
Write-Output "  Files scanned: $(@($utilCandidates | ForEach-Object { $_.file } | Select-Object -Unique).Count)"
Write-Output "  Candidate utilities: $($utilCandidates.Count)"
Write-Output "  Installed libs: $($installedLibs.Count)"

$result = @{
    candidates = $utilCandidates
    installedLibs = $installedLibs
    semanticHints = $semanticHints
    counts = @{
        scannedFiles = (@($utilCandidates | ForEach-Object { $_.file } | Select-Object -Unique)).Count
        candidates = $utilCandidates.Count
        installedLibs = $installedLibs.Count
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
