[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$OldSchema = "v1/schema.sql",
    [string]$NewSchema = "v2/schema.sql"
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

$oldPath = Join-Path $ProjectDir $OldSchema
$newPath = Join-Path $ProjectDir $NewSchema

if (-not (Test-Path $oldPath)) {
    Write-Error "Old schema not found: $oldPath"
    exit 1
}
if (-not (Test-Path $newPath)) {
    Write-Error "New schema not found: $newPath"
    exit 1
}

# Parse old schema
$oldContent = Get-Content -LiteralPath $oldPath -Raw -ErrorAction SilentlyContinue
if (-not $oldContent) {
    Write-Error "Could not read old schema: $oldPath"
    exit 1
}
Remove-Variable -Name oldSchema -Scope Global -ErrorAction SilentlyContinue
$script:oldSchema = @{}
$oldLines = $oldContent -split "`r`n|`n"
$oldCurrentTable = ''
for ($i = 0; $i -lt $oldLines.Count; $i++) {
    $line = $oldLines[$i].Trim()
    if ($line -match 'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?["`]?(\w+)["`]?') {
        $oldCurrentTable = $matches[1]
        $oldSchema[$oldCurrentTable] = @{
            columns = @{}
            uniques = @()
            fks = @()
        }
        continue
    }
    if ($oldCurrentTable -and $line -match '^\s*(\w+)\s+(\w+)') {
        $colName = $matches[1]
        $colType = $matches[2]
        if ($colName -in @('PRIMARY', 'FOREIGN', 'UNIQUE', 'CHECK', 'CONSTRAINT', 'KEY', 'INDEX')) {
            if ($line -match 'UNIQUE\s*\(\s*(\w+)\s*\)') {
                $oldSchema[$oldCurrentTable].uniques += $matches[1]
            }
            if ($line -match 'FOREIGN\s+KEY\s*\(\s*(\w+)\s*\)\s*REFERENCES\s+(\w+)') {
                $oldSchema[$oldCurrentTable].fks += @{ column = $matches[1]; refTable = $matches[2] }
            }
            continue
        }
        $nullable = -not ($line -match 'NOT\s+NULL')
        $default = ''
        if ($line -match 'DEFAULT\s+(\S+)') { $default = $matches[1] }
        $oldSchema[$oldCurrentTable].columns[$colName] = @{
            type = $colType
            nullable = $nullable
            default = $default
        }
    }
}

# Parse new schema
$newContent = Get-Content -LiteralPath $newPath -Raw -ErrorAction SilentlyContinue
Remove-Variable -Name newSchema -Scope Global -ErrorAction SilentlyContinue
$script:newSchema = @{}
if ($newContent) {
    $newLines = $newContent -split "`r`n|`n"
    $newCurrentTable = ''
    for ($i = 0; $i -lt $newLines.Count; $i++) {
        $line = $newLines[$i].Trim()
        if ($line -match 'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?["`]?(\w+)["`]?') {
            $newCurrentTable = $matches[1]
            $newSchema[$newCurrentTable] = @{
                columns = @{}
                uniques = @()
                fks = @()
            }
            continue
        }
        if ($newCurrentTable -and $line -match '^\s*(\w+)\s+(\w+)') {
            $colName = $matches[1]
            $colType = $matches[2]
            if ($colName -in @('PRIMARY', 'FOREIGN', 'UNIQUE', 'CHECK', 'CONSTRAINT', 'KEY', 'INDEX')) {
                if ($line -match 'UNIQUE\s*\(\s*(\w+)\s*\)') {
                    $newSchema[$newCurrentTable].uniques += $matches[1]
                }
                if ($line -match 'FOREIGN\s+KEY\s*\(\s*(\w+)\s*\)\s*REFERENCES\s+(\w+)') {
                    $newSchema[$newCurrentTable].fks += @{ column = $matches[1]; refTable = $matches[2] }
                }
                continue
            }
            $nullable = -not ($line -match 'NOT\s+NULL')
            $default = ''
            if ($line -match 'DEFAULT\s+(\S+)') { $default = $matches[1] }
            $newSchema[$newCurrentTable].columns[$colName] = @{
                type = $colType
                nullable = $nullable
                default = $default
            }
        }
    }
}

$diff = @()

$allTables = @($oldSchema.Keys) | Sort-Object
foreach ($t in $newSchema.Keys) { if ($allTables -notcontains $t) { $allTables += $t } }
$allTables = $allTables | Sort-Object

foreach ($table in $allTables) {
    if (-not $oldSchema.ContainsKey($table)) {
        $diff += @{
            type = 'table'
            table = $table
            column = ''
            old = ''
            new = 'exists'
            requiresPreCheck = $false
            requiresPostCheck = $true
        }
        continue
    }
    if (-not $newSchema.ContainsKey($table)) {
        $diff += @{
            type = 'table'
            table = $table
            column = ''
            old = 'exists'
            new = ''
            requiresPreCheck = $false
            requiresPostCheck = $true
        }
        continue
    }

    $oldCols = $oldSchema[$table].columns
    $newCols = $newSchema[$table].columns

    $allCols = @($oldCols.Keys) | Sort-Object
    foreach ($c in $newCols.Keys) { if ($allCols -notcontains $c) { $allCols += $c } }
    $allCols = $allCols | Sort-Object

    foreach ($col in $allCols) {
        if (-not $oldCols.ContainsKey($col)) {
            $diff += @{
                type = 'column'
                table = $table
                column = $col
                old = 'missing'
                new = $newCols[$col].type
                requiresPreCheck = $false
                requiresPostCheck = $true
            }
            continue
        }
        if (-not $newCols.ContainsKey($col)) {
            $diff += @{
                type = 'column'
                table = $table
                column = $col
                old = $oldCols[$col].type
                new = 'removed'
                requiresPreCheck = $false
                requiresPostCheck = $true
            }
            continue
        }

        $oldCol = $oldCols[$col]
        $newCol = $newCols[$col]

        if ($oldCol.type -ne $newCol.type) {
            $diff += @{
                type = 'column_type'
                table = $table
                column = $col
                old = $oldCol.type
                new = $newCol.type
                requiresPreCheck = $true
                requiresPostCheck = $true
            }
        }

        if ($oldCol.nullable -ne $newCol.nullable) {
            $diff += @{
                type = 'nullability'
                table = $table
                column = $col
                old = if ($oldCol.nullable) { 'NULL' } else { 'NOT NULL' }
                new = if ($newCol.nullable) { 'NULL' } else { 'NOT NULL' }
                requiresPreCheck = -not $newCol.nullable
                requiresPostCheck = $true
            }
        }
    }

    $oldUniques = $oldSchema[$table].uniques
    $newUniques = $newSchema[$table].uniques
    foreach ($u in $newUniques) {
        if ($oldUniques -notcontains $u) {
            $diff += @{
                type = 'unique_constraint'
                table = $table
                column = $u
                old = 'none'
                new = 'unique'
                requiresPreCheck = $true
                requiresPostCheck = $true
            }
        }
    }
}

$byType = @{}
foreach ($d in $diff) {
    $t = $d.type
    if (-not $byType.ContainsKey($t)) { $byType[$t] = 0 }
    $byType[$t]++
}

$result = @{
    diff = $diff
    counts = @{
        tablesCompared = $allTables.Count
        totalChanges = $diff.Count
        byType = $byType
    }
}

Write-Output "=== Migration Diff Complete ==="
Write-Output "  Tables compared: $($allTables.Count)"
Write-Output "  Total changes: $($diff.Count)"
foreach ($typeKey in $byType.Keys) {
    Write-Output "  $typeKey : $($byType[$typeKey])"
}

Write-Output ($result | ConvertTo-Json -Depth 5)
exit 0
