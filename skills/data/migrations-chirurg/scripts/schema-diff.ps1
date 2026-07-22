[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$OldSchema,

    [Parameter(Mandatory = $true)]
    [string]$NewSchema,

    [ValidateSet('sql', 'prisma', 'auto')]
    [string]$Format = 'auto'
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $OldSchema)) {
    Write-Error "OldSchema existiert nicht: $OldSchema"
    exit 1
}
if (-not (Test-Path -LiteralPath $NewSchema)) {
    Write-Error "NewSchema existiert nicht: $NewSchema"
    exit 1
}

function Get-SchemaText($path) {
    if ((Get-Item -LiteralPath $path).PSIsContainer) {
        $files = Get-ChildItem -LiteralPath $path -Recurse -File -Include '*.sql', '*.prisma' -ErrorAction SilentlyContinue
        return ($files | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
    }
    return Get-Content -LiteralPath $path -Raw
}

function Get-DetectedFormat($path, $text) {
    if ((Get-Item -LiteralPath $path).PSIsContainer) {
        $hasSql = @(Get-ChildItem -LiteralPath $path -Recurse -File -Filter '*.sql' -ErrorAction SilentlyContinue).Count -gt 0
        $hasPrisma = @(Get-ChildItem -LiteralPath $path -Recurse -File -Filter '*.prisma' -ErrorAction SilentlyContinue).Count -gt 0
        if ($hasPrisma -and -not $hasSql) { return 'prisma' }
        return 'sql'
    }
    if ($path -match '(?i)\.prisma$') { return 'prisma' }
    if ($text -match '(?i)\bmodel\s+\w+\s*\{' -and $text -notmatch '(?i)CREATE\s+TABLE') { return 'prisma' }
    return 'sql'
}

$oldText = Get-SchemaText $OldSchema
$newText = Get-SchemaText $NewSchema

$oldFormat = if ($Format -eq 'auto') { Get-DetectedFormat $OldSchema $oldText } else { $Format }
$newFormat = if ($Format -eq 'auto') { Get-DetectedFormat $NewSchema $newText } else { $Format }

if ($oldFormat -ne $newFormat) {
    Write-Error "Format-Mix nicht unterstuetzt: OldSchema erkannt als '$oldFormat', NewSchema als '$newFormat'. Beide Staende muessen dasselbe Format nutzen."
    exit 1
}
$detectedFormat = $oldFormat

# --- Hilfsfunktionen: klammer-tiefen-bewusstes Zerlegen (NUMERIC(10,2) darf nicht
#     als Spalten-Trenner missverstanden werden) ---
function Split-TopLevel([string]$text, [char]$sep) {
    $parts = New-Object System.Collections.Generic.List[string]
    $depth = 0
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $text.ToCharArray()) {
        if ($ch -eq '(') { $depth++ }
        elseif ($ch -eq ')') { $depth-- }
        if ($ch -eq $sep -and $depth -eq 0) {
            $parts.Add($sb.ToString())
            [void]$sb.Clear()
        } else {
            [void]$sb.Append($ch)
        }
    }
    if ($sb.Length -gt 0) { $parts.Add($sb.ToString()) }
    return @($parts)
}

function Get-ParenBlock([string]$text, [int]$openParenIdx) {
    $depth = 0
    for ($i = $openParenIdx; $i -lt $text.Length; $i++) {
        if ($text[$i] -eq '(') { $depth++ }
        elseif ($text[$i] -eq ')') {
            $depth--
            if ($depth -eq 0) { return $text.Substring($openParenIdx + 1, $i - $openParenIdx - 1) }
        }
    }
    return $null
}

# --- SQL-Parsing (bewusst pragmatisch, kein voller SQL-Parser - Simplicity First) ---
function Parse-SqlSchema([string]$text) {
    $tables = [ordered]@{}
    $indexes = @()
    $unparsed = @()

    $createTablePattern = '(?i)CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?["`\[]?(\w+)["`\]]?\s*\('
    foreach ($m in [regex]::Matches($text, $createTablePattern)) {
        $tableName = $m.Groups[1].Value
        $openParenIdx = $m.Index + $m.Length - 1
        $body = Get-ParenBlock $text $openParenIdx
        if (-not $body) { continue }

        $columns = [ordered]@{}
        $parts = Split-TopLevel $body ','
        foreach ($rawPart in $parts) {
            $part = $rawPart.Trim()
            if ($part -eq '') { continue }
            if ($part -match '(?i)^(PRIMARY\s+KEY|FOREIGN\s+KEY|UNIQUE|CONSTRAINT|CHECK)\b') {
                continue # Tabellen-weite Constraints - fuer den pragmatischen Diff nicht einzeln modelliert
            }
            $colMatch = [regex]::Match($part, '^["`\[]?(\w+)["`\]]?\s+(.+)$')
            if (-not $colMatch.Success) { continue }
            $colName = $colMatch.Groups[1].Value
            $rest = $colMatch.Groups[2].Value.Trim()
            $typeMatch = [regex]::Match($rest, '^([A-Za-z][\w]*(?:\s*\([^)]*\))?)')
            $colType = if ($typeMatch.Success) { $typeMatch.Value.Trim() } else { $rest }
            $nullable = -not ($rest -match '(?i)\bNOT\s+NULL\b')
            $defaultMatch = [regex]::Match($rest, '(?i)DEFAULT\s+([^\s,]+)')
            $defaultVal = if ($defaultMatch.Success) { $defaultMatch.Groups[1].Value } else { $null }
            $columns[$colName] = [ordered]@{ name = $colName; type = $colType; nullable = $nullable; default = $defaultVal }
        }
        $tables[$tableName] = $columns
    }

    $createIndexPattern = '(?i)CREATE\s+(UNIQUE\s+)?INDEX\s+["`\[]?(\w+)["`\]]?\s+ON\s+["`\[]?(\w+)["`\]]?\s*\(([^)]+)\)'
    foreach ($m in [regex]::Matches($text, $createIndexPattern)) {
        $indexes += [ordered]@{
            name    = $m.Groups[2].Value
            table   = $m.Groups[3].Value
            columns = ($m.Groups[4].Value -split ',' | ForEach-Object { $_.Trim() })
            unique  = [bool]$m.Groups[1].Value
        }
    }

    # Statements, die keine CREATE TABLE / CREATE INDEX sind, als unparsed vermerken
    # (Trigger, Views, Funktionen, ALTER TABLE - bewusst nicht modelliert).
    $stmtPattern = '(?im)^\s*(CREATE\s+(?:OR\s+REPLACE\s+)?(?:TRIGGER|VIEW|FUNCTION|SEQUENCE)|ALTER\s+TABLE)\b'
    $lineNum = 0
    foreach ($line in ($text -split "`n")) {
        $lineNum++
        if ($line -match $stmtPattern) {
            $unparsed += [ordered]@{ line = $lineNum; text = $line.Trim() }
        }
    }

    return [ordered]@{ tables = $tables; indexes = $indexes; unparsed = $unparsed }
}

# --- Prisma-Parsing (pragmatisch: model-Bloecke -> Felder) ---
function Parse-PrismaSchema([string]$text) {
    $tables = [ordered]@{}
    $modelPattern = '(?i)model\s+(\w+)\s*\{'
    foreach ($m in [regex]::Matches($text, $modelPattern)) {
        $tableName = $m.Groups[1].Value
        $openBraceIdx = $text.IndexOf('{', $m.Index)
        $depth = 0
        $endIdx = -1
        for ($i = $openBraceIdx; $i -lt $text.Length; $i++) {
            if ($text[$i] -eq '{') { $depth++ }
            elseif ($text[$i] -eq '}') { $depth--; if ($depth -eq 0) { $endIdx = $i; break } }
        }
        if ($endIdx -lt 0) { continue }
        $body = $text.Substring($openBraceIdx + 1, $endIdx - $openBraceIdx - 1)
        $columns = [ordered]@{}
        foreach ($rawLine in ($body -split "`n")) {
            $line = $rawLine.Trim()
            if ($line -eq '' -or $line.StartsWith('//') -or $line.StartsWith('@@')) { continue }
            $fm = [regex]::Match($line, '^(\w+)\s+(\S+)(.*)$')
            if (-not $fm.Success) { continue }
            $colName = $fm.Groups[1].Value
            $rawType = $fm.Groups[2].Value
            $nullable = $rawType.EndsWith('?')
            $colType = $rawType.TrimEnd('?', '[', ']')
            $attrs = $fm.Groups[3].Value.Trim()
            $defaultMatch = [regex]::Match($attrs, '@default\(([^)]*)\)')
            $defaultVal = if ($defaultMatch.Success) { $defaultMatch.Groups[1].Value } else { $null }
            $columns[$colName] = [ordered]@{ name = $colName; type = $colType; nullable = $nullable; default = $defaultVal }
        }
        $tables[$tableName] = $columns
    }
    return [ordered]@{ tables = $tables; indexes = @(); unparsed = @() }
}

if ($detectedFormat -eq 'prisma') {
    $oldModel = Parse-PrismaSchema $oldText
    $newModel = Parse-PrismaSchema $newText
} else {
    $oldModel = Parse-SqlSchema $oldText
    $newModel = Parse-SqlSchema $newText
}

# --- Diff ---
$changes = New-Object System.Collections.Generic.List[object]
$renameCandidates = New-Object System.Collections.Generic.List[object]

$oldTableNames = @($oldModel.tables.Keys)
$newTableNames = @($newModel.tables.Keys)

foreach ($t in $newTableNames) {
    if ($oldTableNames -notcontains $t) {
        $changes.Add([ordered]@{ kind = 'table-added'; table = $t })
    }
}
foreach ($t in $oldTableNames) {
    if ($newTableNames -notcontains $t) {
        $changes.Add([ordered]@{ kind = 'table-removed'; table = $t })
    }
}

foreach ($t in $oldTableNames) {
    if ($newTableNames -notcontains $t) { continue }
    $oldCols = $oldModel.tables[$t]
    $newCols = $newModel.tables[$t]
    $removedCols = @()
    $addedCols = @()

    foreach ($c in $oldCols.Keys) {
        if (-not $newCols.Contains($c)) {
            $changes.Add([ordered]@{ kind = 'column-removed'; table = $t; column = $c; type = $oldCols[$c].type })
            $removedCols += $oldCols[$c]
        }
    }
    foreach ($c in $newCols.Keys) {
        if (-not $oldCols.Contains($c)) {
            $changes.Add([ordered]@{ kind = 'column-added'; table = $t; column = $c; type = $newCols[$c].type })
            $addedCols += $newCols[$c]
        }
    }
    foreach ($c in $oldCols.Keys) {
        if (-not $newCols.Contains($c)) { continue }
        $o = $oldCols[$c]; $n = $newCols[$c]
        if ($o.type -ne $n.type -or $o.nullable -ne $n.nullable -or $o.default -ne $n.default) {
            $changes.Add([ordered]@{
                    kind   = 'column-changed'
                    table  = $t
                    column = $c
                    from   = [ordered]@{ type = $o.type; nullable = $o.nullable; default = $o.default }
                    to     = [ordered]@{ type = $n.type; nullable = $n.nullable; default = $n.default }
                })
        }
    }

    foreach ($removed in $removedCols) {
        foreach ($added in $addedCols) {
            $sameType = ($removed.type -eq $added.type)
            if ($sameType) {
                $renameCandidates.Add([ordered]@{ table = $t; removed = $removed.name; added = $added.name; sameType = $true })
            }
        }
    }
}

# Index-Diff (nur fuer SQL modelliert)
$oldIndexKeys = @($oldModel.indexes | ForEach-Object { $_.name })
$newIndexKeys = @($newModel.indexes | ForEach-Object { $_.name })
foreach ($idx in $newModel.indexes) {
    if ($oldIndexKeys -notcontains $idx.name) {
        $changes.Add([ordered]@{ kind = 'index-added'; table = $idx.table; index = $idx.name; columns = $idx.columns })
    }
}
foreach ($idx in $oldModel.indexes) {
    if ($newIndexKeys -notcontains $idx.name) {
        $changes.Add([ordered]@{ kind = 'index-removed'; table = $idx.table; index = $idx.name })
    }
}

$unparsedAll = @($oldModel.unparsed) + @($newModel.unparsed)

$summary = [ordered]@{
    tablesAdded    = @($changes | Where-Object { $_.kind -eq 'table-added' }).Count
    tablesRemoved  = @($changes | Where-Object { $_.kind -eq 'table-removed' }).Count
    columnsAdded   = @($changes | Where-Object { $_.kind -eq 'column-added' }).Count
    columnsRemoved = @($changes | Where-Object { $_.kind -eq 'column-removed' }).Count
    columnsChanged = @($changes | Where-Object { $_.kind -eq 'column-changed' }).Count
    indexesAdded   = @($changes | Where-Object { $_.kind -eq 'index-added' }).Count
    indexesRemoved = @($changes | Where-Object { $_.kind -eq 'index-removed' }).Count
}

$result = [ordered]@{
    format           = $detectedFormat
    changes          = $changes.ToArray()
    renameCandidates = $renameCandidates.ToArray()
    unparsed         = $unparsedAll
    summary          = $summary
}

Write-Output (ConvertTo-Json $result -Depth 8)

Write-Output "`n=== SCHEMA-DIFF ==="
Write-Output "  Format: $detectedFormat"
Write-Output "  Aenderungen: $($changes.Count) (Tabellen +$($summary.tablesAdded)/-$($summary.tablesRemoved), Spalten +$($summary.columnsAdded)/-$($summary.columnsRemoved)/~$($summary.columnsChanged), Indizes +$($summary.indexesAdded)/-$($summary.indexesRemoved))"
Write-Output "  Rename-Kandidaten: $($renameCandidates.Count)"
if ($unparsedAll.Count -gt 0) { Write-Output "  WARNUNG: $($unparsedAll.Count) nicht geparste Statements - manuell pruefen." }
