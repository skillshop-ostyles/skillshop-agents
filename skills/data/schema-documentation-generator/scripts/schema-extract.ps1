[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [ValidateSet('sql', 'prisma', 'auto')]
    [string]$Format = 'auto',

    [string]$Extensions = '*.sql,*.prisma'
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir does not exist: $ProjectDir"
    exit 1
}

# -- Abbreviation detection and expansion --
$abbreviationMap = [ordered]@{
    'cst'   = 'customer'
    'ord'   = 'order'
    'prd'   = 'product'
    'nm'    = 'name'
    'dt'    = 'date'
    'sts'   = 'status'
    'flg'   = 'flag'
    'qty'   = 'quantity'
    'amt'   = 'amount'
    'addr'  = 'address'
    'descr' = 'description'
    'ref'   = 'reference'
    'id'    = 'identifier'
    'phn'   = 'phone'
    'cat'   = 'category'
    'crt'   = 'created'
    'mod'   = 'modified'
    'email' = 'email'
    'price' = 'price'
    'desc'  = 'description'
    'total' = 'total'
    'active' = 'active'
}

$abbreviationPatterns = @('cst', 'ord', 'prd', 'nm', 'dt', 'sts', 'flg', 'qty', 'amt', 'addr', 'descr', 'ref', 'id', 'phn', 'cat', 'crt', 'mod', 'email', 'price', 'desc', 'total', 'active')

function Test-IsAbbreviated([string]$name) {
    if ($name.Length -lt 6) { return $true }
    $parts = $name -split '_'
    foreach ($part in $parts) {
        if ($abbreviationPatterns -contains $part.ToLower()) { return $true }
    }
    return $false
}

function Get-InferredMeaning([string]$name) {
    $parts = $name -split '_'
    $expanded = @()
    foreach ($part in $parts) {
        $lower = $part.ToLower()
        if ($abbreviationMap.Contains($lower)) {
            $expanded += $abbreviationMap[$lower]
        } else {
            $expanded += $part
        }
    }
    return ($expanded -join ' ')
}

# -- Helper: parenthesis-depth-aware splitting --
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

# -- Collect files --
$extList = $Extensions -split ',' | ForEach-Object { $_.Trim() }
$files = Get-ChildItem -LiteralPath $ProjectDir -Recurse -File -Include $extList -ErrorAction SilentlyContinue

if ($files.Count -eq 0) {
    Write-Error "No DDL/ORM files found matching extensions: $Extensions"
    exit 1
}

# -- Parse each file --
$schemaTables = [ordered]@{}
$allRelationships = New-Object System.Collections.Generic.List[object]
$allIndexes = New-Object System.Collections.Generic.List[object]
$allUniqueConstraints = New-Object System.Collections.Generic.List[object]

foreach ($file in $files) {
    $text = Get-Content -LiteralPath $file.FullName -Raw

    # Detect format
    $detectedFormat = $Format
    if ($detectedFormat -eq 'auto') {
        if ($file.Extension -eq '.prisma' -or $text -match '(?i)\bmodel\s+\w+\s*\{') {
            $detectedFormat = 'prisma'
        } else {
            $detectedFormat = 'sql'
        }
    }

    if ($detectedFormat -eq 'prisma') {
        # Parse Prisma models
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

            $columns = New-Object System.Collections.Generic.List[object]
            $tableIndexes = New-Object System.Collections.Generic.List[object]
            $tableUniqueConstraints = New-Object System.Collections.Generic.List[object]

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
                $isAbbreviated = Test-IsAbbreviated $colName
                $inferredMeaning = if ($isAbbreviated) { Get-InferredMeaning $colName } else { $null }

                $columns.Add([ordered]@{
                    name = $colName
                    type = $colType
                    nullable = $nullable
                    default = $defaultVal
                    isAbbreviated = $isAbbreviated
                    inferredMeaning = $inferredMeaning
                })
            }

            $schemaTables[$tableName] = [ordered]@{
                columns = $columns.ToArray()
                relationships = @()
                indexes = $tableIndexes.ToArray()
                uniqueConstraints = $tableUniqueConstraints.ToArray()
            }
        }
    } else {
        # Parse SQL DDL
        $createTablePattern = '(?i)CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?["`\[]?(\w+)["`\]]?\s*\('
        foreach ($m in [regex]::Matches($text, $createTablePattern)) {
            $tableName = $m.Groups[1].Value
            $openParenIdx = $m.Index + $m.Length - 1
            $body = Get-ParenBlock $text $openParenIdx
            if (-not $body) { continue }

            $columns = New-Object System.Collections.Generic.List[object]
            $tableIndexes = New-Object System.Collections.Generic.List[object]
            $tableUniqueConstraints = New-Object System.Collections.Generic.List[object]

            $parts = Split-TopLevel $body ','
            foreach ($rawPart in $parts) {
                $part = $rawPart.Trim()
                if ($part -eq '') { continue }

                # Check for table-level constraints
                if ($part -match '(?i)^PRIMARY\s+KEY\s*\(([^)]+)\)') {
                    # PK columns - we note them but don't add as separate columns
                    continue
                }
                if ($part -match '(?i)^FOREIGN\s+KEY\s*\((\w+)\)\s*REFERENCES\s+(\w+)\s*\((\w+)\)') {
                    $allRelationships.Add([ordered]@{
                        fromTable = $tableName
                        fromCol = $Matches[1]
                        toTable = $Matches[2]
                        toCol = $Matches[3]
                    })
                    continue
                }
                if ($part -match '(?i)^UNIQUE\s*(?:KEY\s+["`\[]?\w+["`\]]?\s*)?\(([^)]+)\)') {
                    $uniqueCols = $Matches[1] -split ',' | ForEach-Object { $_.Trim().Trim('"', '`', '[', ']') }
                    $tableUniqueConstraints.Add([ordered]@{
                        table = $tableName
                        columns = $uniqueCols
                    })
                    continue
                }
                if ($part -match '(?i)^INDEX\s+["`\[]?(\w+)["`\]]?\s*\(([^)]+)\)') {
                    $tableIndexes.Add([ordered]@{
                        name = $Matches[1]
                        table = $tableName
                        columns = ($Matches[2] -split ',' | ForEach-Object { $_.Trim().Trim('"', '`', '[', ']') })
                        unique = $false
                    })
                    continue
                }
                if ($part -match '(?i)^CONSTRAINT\s+["`\[]?(\w+)["`\]]?\s+(PRIMARY\s+KEY|FOREIGN\s+KEY|UNIQUE|CHECK)') {
                    $constraintType = $Matches[2]
                    if ($constraintType -match '(?i)PRIMARY\s+KEY') {
                        continue
                    }
                    if ($constraintType -match '(?i)FOREIGN\s+KEY') {
                        $fkInner = [regex]::Match($part, '(?i)FOREIGN\s+KEY\s*\((\w+)\)\s*REFERENCES\s+(\w+)\s*\((\w+)\)')
                        if ($fkInner.Success) {
                            $allRelationships.Add([ordered]@{
                                fromTable = $tableName
                                fromCol = $fkInner.Groups[1].Value
                                toTable = $fkInner.Groups[2].Value
                                toCol = $fkInner.Groups[3].Value
                            })
                        }
                        continue
                    }
                    if ($constraintType -match '(?i)UNIQUE') {
                        $uniqueInner = [regex]::Match($part, '\(([^)]+)\)')
                        if ($uniqueInner.Success) {
                            $uniqueCols = $uniqueInner.Groups[1].Value -split ',' | ForEach-Object { $_.Trim().Trim('"', '`', '[', ']') }
                            $tableUniqueConstraints.Add([ordered]@{
                                table = $tableName
                                columns = $uniqueCols
                            })
                        }
                        continue
                    }
                    continue
                }

                # Column definition
                $colMatch = [regex]::Match($part, '^["`\[]?(\w+)["`\]]?\s+(.+)$')
                if (-not $colMatch.Success) { continue }
                $colName = $colMatch.Groups[1].Value
                $rest = $colMatch.Groups[2].Value.Trim()

                $typeMatch = [regex]::Match($rest, '^([A-Za-z][\w]*(?:\s*\([^)]*\))?)')
                $colType = if ($typeMatch.Success) { $typeMatch.Value.Trim() } else { $rest }

                $nullable = -not ($rest -match '(?i)\bNOT\s+NULL\b')
                $defaultMatch = [regex]::Match($rest, '(?i)DEFAULT\s+([^\s,;]+)')
                $defaultVal = if ($defaultMatch.Success) { $defaultMatch.Groups[1].Value.Trim("'", '"') } else { $null }

                $isAbbreviated = Test-IsAbbreviated $colName
                $inferredMeaning = if ($isAbbreviated) { Get-InferredMeaning $colName } else { $null }

                $columns.Add([ordered]@{
                    name = $colName
                    type = $colType
                    nullable = $nullable
                    default = $defaultVal
                    isAbbreviated = $isAbbreviated
                    inferredMeaning = $inferredMeaning
                })
            }

            $schemaTables[$tableName] = [ordered]@{
                columns = $columns.ToArray()
                relationships = @()
                indexes = $tableIndexes.ToArray()
                uniqueConstraints = $tableUniqueConstraints.ToArray()
            }
        }
    }
}

# -- Collect abbreviations used --
$abbreviationsUsed = [ordered]@{}

# -- Build output --
$outputTables = New-Object System.Collections.Generic.List[object]
$totalColumns = 0
$unnamedCount = 0

foreach ($tableName in $schemaTables.Keys) {
    $tableData = $schemaTables[$tableName]
    $tableColumns = $tableData.columns
    $tableRelationships = $tableData.relationships
    $tableIndexes = $tableData.indexes
    $tableUniqueConstraints = $tableData.uniqueConstraints

    $totalColumns += $tableColumns.Count

    $colList = New-Object System.Collections.Generic.List[object]
    foreach ($col in $tableColumns) {
        if ($col.isAbbreviated) { $unnamedCount++ }

        # Track abbreviations used
        $parts = $col.name -split '_'
        foreach ($part in $parts) {
            $lower = $part.ToLower()
            if ($abbreviationMap.Contains($lower) -and -not $abbreviationsUsed.Contains($lower)) {
                $abbreviationsUsed[$lower] = $abbreviationMap[$lower]
            }
        }

        $colList.Add([ordered]@{
            name = $col.name
            type = $col.type
            nullable = $col.nullable
            default = $col.default
            isAbbreviated = $col.isAbbreviated
            inferredMeaning = $col.inferredMeaning
        })
    }

    $outputTables.Add([ordered]@{
        table = $tableName
        columns = $colList.ToArray()
        relationships = $tableRelationships
        indexes = $tableIndexes
        uniqueConstraints = $tableUniqueConstraints
    })
}

# -- Build output --
$output = [ordered]@{
    schema = $outputTables.ToArray()
    relationships = $allRelationships.ToArray()
    metrics = [ordered]@{
        tableCount = $outputTables.Count
        columnCount = $totalColumns
        fkCount = $allRelationships.Count
        unnamedRatio = if ($totalColumns -gt 0) { [math]::Round(($unnamedCount / $totalColumns) * 100, 1) } else { 0 }
    }
}

$json = ConvertTo-Json $output -Depth 8
Write-Output $json

# -- Console summary --
Write-Output "`n=== SCHEMA-EXTRACT ==="
Write-Output "  Tables: $($outputTables.Count)"
Write-Output "  Columns: $totalColumns"
Write-Output "  Foreign Keys: $($allRelationships.Count)"
Write-Output "  Unnamed ratio: $($output.metrics.unnamedRatio)%"
Write-Output "  Abbreviations detected: $($abbreviationsUsed.Count)"
foreach ($kv in $abbreviationsUsed.GetEnumerator()) {
    Write-Output "    $($kv.Key) -> $($kv.Value)"
}

exit 0
