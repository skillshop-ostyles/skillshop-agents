[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.cs,*.go,*.java,*.rb,*.php",
    [string]$Exclude = "",
    [int]$MaxParams = 12
)

$ErrorActionPreference = 'Stop'
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

# Extract exported function/method signatures.
function Get-Signatures($content) {
    $sigs = @()
    $lines = $content -split "`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        # Capture multi-line signatures: function NAME(args, args, args) { ... }
        if ($line -match '^\s*(export\s+)?(public\s+|private\s+|protected\s+|static\s+)*(async\s+)?function\s+(\w+)([^()]*)\(([^)]*)\)') {
            $name = $matches[4]
            $paramsText = $matches[6]
            $params = @()
            if ($paramsText.Trim()) {
                # Split on commas - heuristics tolerate commas in defaults.
                $depth = 0; $current = ''
                foreach ($c in $paramsText.ToCharArray()) {
                    if ($c -eq '(' -or $c -eq '[' -or $c -eq '{' -or $c -eq '<') { $depth++ }
                    elseif ($c -eq ')' -or $c -eq ']' -or $c -eq '}' -or $c -eq '>') { $depth-- }
                    if ($c -eq ',' -and $depth -eq 0) {
                        $params += $current.Trim()
                        $current = ''
                    } else { $current += $c }
                }
                if ($current.Trim()) { $params += $current.Trim() }
            }
            $sigs += @{
                name = $name
                paramCount = $params.Count
                params = $params
                line = $i + 1
            }
        }
    }
    return ,$sigs
}

$signatures = @()
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
        foreach ($s in (Get-Signatures $content)) {
            $s.file = $rel
            $signatures += $s
        }
    }
}

# Heuristic detection patterns:
# 1. Boolean-trap: param is bare bool (a, b, c, true, false).
# 2. Same-type adjacent: two params of same type adjacent.
# 3. Default-surprise: defaults vary across similar-named functions.
$findings = @()

# Boolean params: capture as a property per signature.
foreach ($s in $signatures) {
    $bools = @()
    foreach ($p in $s.params) {
        if ($p -match ':\s*(boolean|bool)\b' -or $p -match ':\s*Boolean\b' -or $p -match ':\s*Optional\[bool\]') {
            $bools += $p
        }
    }
    if ($bools.Count -gt 0) {
        $s.hasBooleanParam = $true
        $s.booleanParamCount = $bools.Count
    }
}

# Same-type adjacent: find pairs of params where the type tokens match.
foreach ($s in $signatures) {
    if ($null -eq $s.params) { continue }
    $adj = @()
    for ($i = 0; $i -lt ($s.params.Count - 1); $i++) {
        $cur = $s.params[$i]
        $next = $s.params[$i + 1]
        $tCur = if ($cur -match ':\s*(\S+?)\??\s*(?=,|\)|$)') { $matches[1] } else { $null }
        $tNext = if ($next -match ':\s*(\S+?)\??\s*(?=,|\)|$)') { $matches[1] } else { $null }
        if ($tCur -and $tNext -and $tCur -eq $tNext) {
            $adj += "$cur, $next"
        }
    }
    if ($adj.Count -gt 0) {
        $s.sameTypeAdjacent = $adj
    }
}

# Group by name similarity: create*/update*/fetch*/get*/find* should share conventions.
$similarityGroups = @{}
foreach ($s in $signatures) {
    $base = $s.name -replace '(creat|update|fetch|get|find|save|delet|remov|add|insert).*$', '$1'
    if ($base -eq $s.name) { continue }
    if (-not $similarityGroups.ContainsKey($base)) { $similarityGroups[$base] = @() }
    $similarityGroups[$base] += $s
}

# Aggregate findings.
foreach ($s in $signatures) {
    if ($s.booleanParamCount -gt 1) {
        $findings += @{
            kind = 'boolean-trap'
            severity = 'high'
            file = $s.file
            line = $s.line
            function = $s.name
            note = "Multiple boolean params ($($s.booleanParamCount)): callers must remember positional order; boolean trap risk."
        }
    }
    if ($s.sameTypeAdjacent -and $s.sameTypeAdjacent.Count -gt 0) {
        $findings += @{
            kind = 'same-type-adjacent'
            severity = 'high'
            file = $s.file
            line = $s.line
            function = $s.name
            note = "Two adjacent params of the same type: swap risk (e.g., from/to, save/fetchUntil=$($s.sameTypeAdjacent[0])."
        }
    }
}

foreach ($base in $similarityGroups.Keys) {
    $members = $similarityGroups[$base]
    if ($members.Count -lt 2) { continue }
    $paramCounts = $members | ForEach-Object { $_.paramCount } | Sort-Object -Unique
    if ($paramCounts.Count -gt 1) {
        $funNames = ($members | ForEach-Object { "$($_.name)($($_.paramCount))" }) -join ', '
        $findings += @{
            kind = 'inconsistent-defaults'
            severity = 'medium'
            file = $members[0].file
            line = $members[0].line
            function = $members[0].name
            note = "Family ${base}*: signatures inconsistent ($funNames). Hard to remember arity/order."
        }
    }
}

Write-Output "=== Footgun Review Complete ==="
Write-Output "  Files scanned: $(@($signatures | ForEach-Object { $_.file } | Select-Object -Unique).Count)"
Write-Output "  Signatures: $($signatures.Count)"
Write-Output "  Findings: $($findings.Count)"
foreach ($f in $findings) {
    Write-Output "  $($f.kind): $($f.function) - $($f.severity)"
}

$result = @{
    signatures = $signatures
    similarityGroups = $similarityGroups
    findings = $findings
    counts = @{
        scannedFiles = (@($signatures | ForEach-Object { $_.file } | Select-Object -Unique)).Count
        signatures = $signatures.Count
        findings = $findings.Count
    }
}

Write-Output ($result | ConvertTo-Json -Depth 6)
exit 0
