[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('ts', 'tsx', 'js', 'jsx', 'py', 'cs', 'go', 'rs', 'java', 'php', 'rb', 'vue', 'sql', 'prisma', 'graphql', 'proto', 'json', 'yaml', 'yml'),
    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage', '*.min.*', '*generated*'),
    [int]$MinFrequency = 2,
    [int]$TopN = 400
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir existiert nicht: $ProjectDir"
    exit 1
}

$root = (Resolve-Path -LiteralPath $ProjectDir).Path
$extSet = @($Extensions | ForEach-Object { $_.TrimStart('.').ToLower() })
$dirExcludes = @($Exclude | Where-Object { $_ -notmatch '[*?]' } | ForEach-Object { $_.ToLower() })
$globExcludes = @($Exclude | Where-Object { $_ -match '[*?]' })

function Test-ExcludedPath($fullPath) {
    $rel = $fullPath.Substring($root.Length).TrimStart('\', '/')
    $leaf = Split-Path $fullPath -Leaf
    foreach ($part in ($rel -split '[\\/]')) {
        if ($dirExcludes -contains $part.ToLower()) { return $true }
    }
    foreach ($pattern in $globExcludes) {
        if ($leaf -like $pattern) { return $true }
    }
    return $false
}

$allFiles = @(
    Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
        Where-Object { -not (Test-ExcludedPath $_.FullName) }
)

$stopwords = @('get', 'set', 'is', 'has', 'new', 'id', 'data', 'info', 'item', 'list', 'map', 'util', 'helper', 'impl', 'tmp', 'obj', 'val', 'res', 'req')
$stopwordSet = New-Object System.Collections.Generic.HashSet[string]
foreach ($w in $stopwords) { [void]$stopwordSet.Add($w) }

function Split-IdentifierToTerms([string]$ident) {
    # -creplace (case-SENSITIV) ist hier zwingend: das normale -replace ist in
    # PowerShell case-insensitiv, wodurch [a-z0-9] und [A-Z] beide jeden
    # Buchstaben treffen und die CamelCase-Grenze faelschlich zwischen JEDEM
    # Zeichenpaar einfuegen wuerden (z.B. "createCustomer" -> "c re at eC...").
    $s = $ident -creplace '([a-z0-9])([A-Z])', '$1 $2'
    $s = $s -creplace '([A-Z]+)([A-Z][a-z])', '$1 $2'
    $s = $s -replace '[_\-]+', ' '
    $parts = @($s -split '\s+' | Where-Object { $_ -ne '' })
    $terms = @()
    foreach ($p in $parts) {
        $lower = $p.ToLower()
        if ($lower.Length -ge 3 -and -not $stopwordSet.Contains($lower)) { $terms += $lower }
    }
    return $terms
}

$termMap = [ordered]@{}
$totalIdentifiers = 0

function Add-Identifier([string]$ident, [string]$source, [string]$relPath, [int]$lineNum) {
    if ($ident -eq '') { return }
    $script:totalIdentifiers += 1
    $terms = Split-IdentifierToTerms $ident
    foreach ($term in $terms) {
        if (-not $termMap.Contains($term)) {
            $termMap[$term] = [ordered]@{
                term      = $term
                frequency = 0
                sources   = [ordered]@{ code = 0; schema = 0; api = 0 }
                samples   = New-Object System.Collections.Generic.List[object]
            }
        }
        $entry = $termMap[$term]
        $entry.frequency += 1
        $entry.sources[$source] += 1
        if ($entry.samples.Count -lt 10) {
            $entry.samples.Add([ordered]@{ file = $relPath; line = $lineNum; identifier = $ident })
        }
    }
}

# --- Regex-Familien ---
$codeDeclRegex = '\b(class|interface|type|function|def|const|let|var|struct|enum)\s+(\w+)'
$tsPropRegex = '^\s*([A-Za-z_][A-Za-z0-9_]*)\??\s*:\s*[\w\[\]<>|."'']'
$sqlCreateTableRegex = '(?i)CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?[`"\[]?(\w+)'
$sqlColumnRegex = '(?i)^\s*[`"\[]?([a-zA-Z_][a-zA-Z0-9_]*)[`"\]]?\s+(INT\w*|VARCHAR\w*|TEXT|BOOLEAN|BOOL|DATE\w*|TIMESTAMP\w*|SERIAL\w*|UUID|DECIMAL\w*|FLOAT\w*|CHAR\w*|BIGINT|NUMERIC\w*)\b'
$prismaModelRegex = '(?i)^\s*model\s+(\w+)'
$prismaFieldRegex = '^\s*([A-Za-z_][A-Za-z0-9_]*)\s+(String|Int|Boolean|DateTime|Float|Json|BigInt|Bytes|Decimal)\b'
$graphqlTypeRegex = '(?i)^\s*type\s+(\w+)'
$graphqlFieldRegex = '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:\s*[\w\[\]!]+'
$protoMessageRegex = '(?i)^\s*message\s+(\w+)'
$protoFieldRegex = '^\s*(?:optional|repeated|required)?\s*[\w.]+\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*\d+\s*;'
$jsonKeyRegex = '"([A-Za-z_][A-Za-z0-9_]*)"\s*:'

foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $ext = $f.Extension.TrimStart('.').ToLower()
    $lines = @(Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue)

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = [string]$lines[$i]
        $lineNum = $i + 1

        if ($ext -in @('sql')) {
            $m = [regex]::Match($line, $sqlCreateTableRegex)
            if ($m.Success) { Add-Identifier $m.Groups[1].Value 'schema' $relPath $lineNum }
            $m = [regex]::Match($line, $sqlColumnRegex)
            if ($m.Success) { Add-Identifier $m.Groups[1].Value 'schema' $relPath $lineNum }
        } elseif ($ext -eq 'prisma') {
            $m = [regex]::Match($line, $prismaModelRegex)
            if ($m.Success) { Add-Identifier $m.Groups[1].Value 'schema' $relPath $lineNum }
            $m = [regex]::Match($line, $prismaFieldRegex)
            if ($m.Success) { Add-Identifier $m.Groups[1].Value 'schema' $relPath $lineNum }
        } elseif ($ext -eq 'graphql') {
            $m = [regex]::Match($line, $graphqlTypeRegex)
            if ($m.Success) { Add-Identifier $m.Groups[1].Value 'schema' $relPath $lineNum }
            elseif ($line -match $graphqlFieldRegex) {
                $m = [regex]::Match($line, $graphqlFieldRegex)
                Add-Identifier $m.Groups[1].Value 'schema' $relPath $lineNum
            }
        } elseif ($ext -eq 'proto') {
            $m = [regex]::Match($line, $protoMessageRegex)
            if ($m.Success) { Add-Identifier $m.Groups[1].Value 'schema' $relPath $lineNum }
            $m = [regex]::Match($line, $protoFieldRegex)
            if ($m.Success) { Add-Identifier $m.Groups[1].Value 'schema' $relPath $lineNum }
        } elseif ($ext -eq 'json') {
            foreach ($m in [regex]::Matches($line, $jsonKeyRegex)) {
                Add-Identifier $m.Groups[1].Value 'api' $relPath $lineNum
            }
        } elseif ($ext -in @('yaml', 'yml')) {
            $m = [regex]::Match($line, '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:')
            if ($m.Success) { Add-Identifier $m.Groups[1].Value 'api' $relPath $lineNum }
        } else {
            # Code-Bezeichner (class/interface/type/function/def/const/let/var/struct/enum)
            $m = [regex]::Match($line, $codeDeclRegex)
            if ($m.Success) { Add-Identifier $m.Groups[2].Value 'code' $relPath $lineNum }
            # DTO-/API-Schluessel: Property-artige Zeilen in TS/JS-Interface-/Type-Bloecken
            if ($ext -in @('ts', 'tsx')) {
                $pm = [regex]::Match($line, $tsPropRegex)
                if ($pm.Success -and $m.Success -eq $false) { Add-Identifier $pm.Groups[1].Value 'api' $relPath $lineNum }
            }
        }
    }
}

$allTerms = @($termMap.Values | Where-Object { $_.frequency -ge $MinFrequency })
$sortedTerms = @($allTerms | Sort-Object -Property frequency -Descending)
$truncated = $sortedTerms.Count -gt $TopN
$outTerms = if ($truncated) { $sortedTerms[0..($TopN - 1)] } else { $sortedTerms }

$outTermsFinal = @(
    foreach ($t in $outTerms) {
        # samples NICHT mit @(...) umschliessen: $t.samples ist bereits eine
        # List[object] - das erneute @()-Wrapping als Hashtable-Wert innerhalb
        # eines foreach-in-@()-Blocks loest denselben PSEnumerableBinder-Bug
        # aus wie in Sprint 3 (+= mit verschachtelter Collection), nur diesmal
        # bei direkter Zuweisung. Direkte Zuweisung der bereits-enumerierbaren
        # Liste umgeht den Bug.
        [ordered]@{
            term      = $t.term
            frequency = $t.frequency
            sources   = $t.sources
            samples   = $t.samples
        }
    }
)

$result = [ordered]@{
    terms             = $outTermsFinal
    totalIdentifiers  = $totalIdentifiers
    truncatedToTopN   = $truncated
}

Write-Output (ConvertTo-Json $result -Depth 8)

Write-Output "`n=== VOCAB: TERM-HARVEST ==="
Write-Output "  Gescannte Dateien: $($allFiles.Count)"
Write-Output "  Rohe Bezeichner gesamt: $totalIdentifiers"
Write-Output "  Terme (nach MinFrequency $MinFrequency): $($allTerms.Count)"
Write-Output "  Gekappt auf TopN ${TopN}: $truncated"
