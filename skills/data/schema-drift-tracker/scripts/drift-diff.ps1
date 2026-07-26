<#
.SYNOPSIS
  Compare two SQL DDL schema snapshots and detect schema drift.

.DESCRIPTION
  Parses CREATE TABLE statements from two schema files, diffs tables,
  columns, indexes, and foreign keys, and outputs structured JSON with
  every drift entry. Designed for the schema-drift-tracker skill.

.PARAMETER ProjectDir
  Base path for schema files.

.PARAMETER OldSchema
  Relative path (from ProjectDir) or git ref for the old schema. Default v1/schema.sql.

.PARAMETER NewSchema
  Relative path (from ProjectDir) or git ref for the new schema. Default v2/schema.sql.

.EXAMPLE
  powershell -File drift-diff.ps1 -ProjectDir tests/fixtures/smoke/src -OldSchema v1/schema.sql -NewSchema v2/schema.sql
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [Parameter(Mandatory = $false)]
    [string]$OldSchema = "v1/schema.sql",

    [Parameter(Mandatory = $false)]
    [string]$NewSchema = "v2/schema.sql"
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# ---------------------------------------------------------------
# Helper: walk a path – file or directory – and return raw content
# ---------------------------------------------------------------
function Get-SchemaContent {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Error "Schema path not found: $Path"
        exit 1
    }

    $item = Get-Item -LiteralPath $Path
    if ($item.PSIsContainer) {
        $sb = [System.Text.StringBuilder]::new()
        Get-ChildItem -LiteralPath $Path -Filter *.sql -Recurse | Sort-Object FullName | ForEach-Object {
            $null = $sb.AppendLine((Get-Content -LiteralPath $_.FullName -Raw))
        }
        return $sb.ToString()
    }

    return (Get-Content -LiteralPath $Path -Raw)
}

# ---------------------------------------------------------------
# Parse DDL into a structured schema object
# ---------------------------------------------------------------
function Parse-Schema {
    param([string]$Content, [string]$Label)

    $tables = @{}
    $indexes = @{}
    $foreignKeys = @{}

    # ---- CREATE TABLE ----
    $tablePat = '(?s)CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:`?\w+`?\.)?(`?\w+`?)\s*\((.+?)\)\s*;'
    $tableMatches = [regex]::Matches($Content, $tablePat, 'IgnoreCase')

    foreach ($tm in $tableMatches) {
        $tableName = $tm.Groups[1].Value
        $body = $tm.Groups[2].Value

        # Split body at top-level commas
        $defs = @()
        $depth = 0
        $current = ''
        foreach ($ch in $body.ToCharArray()) {
            if ($ch -eq '(') { $depth++ }
            elseif ($ch -eq ')') { $depth-- }
            if ($ch -eq ',' -and $depth -eq 0) {
                $defs += $current.Trim()
                $current = ''
            } else {
                $current += $ch
            }
        }
        if ($current.Trim() -ne '') {
            $defs += $current.Trim()
        }

        $columns = @()
        $tableFks = @()

        foreach ($def in $defs) {
            if ([string]::IsNullOrWhiteSpace($def)) { continue }

            # FOREIGN KEY constraint
            $fkMatch = [regex]::Match($def, 'FOREIGN\s+KEY\s*\(([^)]+)\)\s*REFERENCES\s+(\w+)\s*\(([^)]+)\)', 'IgnoreCase')
            if ($fkMatch.Success) {
                $fkCols = $fkMatch.Groups[1].Value -split ',\s*' | ForEach-Object { $_.Trim() }
                $refTable = $fkMatch.Groups[2].Value
                $refCols = $fkMatch.Groups[3].Value -split ',\s*' | ForEach-Object { $_.Trim() }
                $tableFks += @{
                    Columns = $fkCols
                    RefTable = $refTable
                    RefColumns = $refCols
                }
                continue
            }

            # Standalone PRIMARY KEY constraint
            $pkConstraint = [regex]::Match($def, '^\s*PRIMARY\s+KEY\s*\(([^)]+)\)\s*$', 'IgnoreCase')
            if ($pkConstraint.Success) { continue }

            # Column definition
            $colPat = '^\s*(`?\w+`?)\s+(\w+(?:\s*\([^)]*\))?(?:\s+UNSIGNED)?(?:\s+SIGNED)?)\s*(PRIMARY\s+KEY)?\s*(NOT\s+NULL|NULL)?\s*(DEFAULT\s+.+?)?\s*,?\s*$'
            $colMatch = [regex]::Match($def, $colPat, 'IgnoreCase')

            if ($colMatch.Success) {
                $colName = $colMatch.Groups[1].Value
                $colType = $colMatch.Groups[2].Value.Trim()
                $isPrimary = $colMatch.Groups[3].Success
                $hasNullSpec = $colMatch.Groups[4].Success
                $nullSpec = if ($hasNullSpec) { $colMatch.Groups[4].Value } else { $null }

                $isNullable = $true
                if ($hasNullSpec -and $nullSpec -eq 'NOT NULL') {
                    $isNullable = $false
                } elseif ($isPrimary) {
                    $isNullable = $false
                }

                $defaultVal = if ($colMatch.Groups[5].Success) { $colMatch.Groups[5].Value.Trim() } else { $null }

                $columns += @{
                    Name       = $colName
                    Type       = $colType
                    Nullable   = $isNullable
                    Default    = $defaultVal
                    PrimaryKey = $isPrimary
                }
            }
        }

        $tables[$tableName] = $columns
        $foreignKeys[$tableName] = $tableFks
    }

    # ---- CREATE INDEX ----
    $idxPat = 'CREATE\s+(UNIQUE\s+)?(INDEX|KEY)\s+(?:`?\w+`?\.)?(`?\w+`?)\s+ON\s+(`?\w+`?)\s*\(([^)]+)\)'
    $idxMatches = [regex]::Matches($Content, $idxPat, 'IgnoreCase')
    foreach ($im in $idxMatches) {
        $idxName = $im.Groups[3].Value
        $tableName = $im.Groups[4].Value
        $idxCols = $im.Groups[5].Value -split ',\s*' | ForEach-Object { $_.Trim() }
        if (-not $indexes.ContainsKey($tableName)) {
            $indexes[$tableName] = @()
        }
        $indexes[$tableName] += @{
            Name    = $idxName
            Columns = $idxCols
        }
    }

    Write-Host "  [$Label] Tables: $($tables.Keys.Count), Indexes: $(($indexes.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum), FKs: $(($foreignKeys.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum)" -ForegroundColor DarkGray

    return @{
        Tables      = $tables
        Indexes     = $indexes
        ForeignKeys = $foreignKeys
    }
}

# ---------------------------------------------------------------
# Resolve paths
# ---------------------------------------------------------------
if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir not found: $ProjectDir"
    exit 1
}

$resolvedOld = Resolve-Path -LiteralPath (Join-Path -Path $ProjectDir -ChildPath $OldSchema) -ErrorAction Stop
$resolvedNew = Resolve-Path -LiteralPath (Join-Path -Path $ProjectDir -ChildPath $NewSchema) -ErrorAction Stop

Write-Host "=== Schema Drift Diff ===" -ForegroundColor Cyan
Write-Host "Old: $resolvedOld" -ForegroundColor Gray
Write-Host "New: $resolvedNew" -ForegroundColor Gray

# ---------------------------------------------------------------
# Parse both schemas
# ---------------------------------------------------------------
$oldContent = Get-SchemaContent -Path $resolvedOld
$newContent = Get-SchemaContent -Path $resolvedNew

$old = Parse-Schema -Content $oldContent -Label 'old'
$new = Parse-Schema -Content $newContent -Label 'new'

# ---------------------------------------------------------------
# Diff logic
# ---------------------------------------------------------------
$drifts = [System.Collections.Generic.List[hashtable]]::new()

$oldTableNames = @($old.Tables.Keys)
$newTableNames = @($new.Tables.Keys)

# --- Removed tables ---
foreach ($tbl in $oldTableNames) {
    if ($tbl -notin $newTableNames) {
        $dep = [System.Collections.Generic.List[string]]::new()
        foreach ($col in $old.Tables[$tbl]) {
            $dep.Add("column $($col.Name)")
        }
        if ($old.Indexes.ContainsKey($tbl)) {
            foreach ($idx in $old.Indexes[$tbl]) {
                $dep.Add("index $($idx.Name)")
            }
        }
        if ($old.ForeignKeys.ContainsKey($tbl)) {
            foreach ($fk in $old.ForeignKeys[$tbl]) {
                $dep.Add("foreign key ($($fk.Columns -join ', ')) -> $($fk.RefTable)")
            }
        }
        foreach ($otherTbl in $oldTableNames) {
            if ($otherTbl -eq $tbl) { continue }
            if ($old.ForeignKeys.ContainsKey($otherTbl)) {
                foreach ($fk in $old.ForeignKeys[$otherTbl]) {
                    if ($fk.RefTable -eq $tbl) {
                        $dep.Add("foreign key in $otherTbl ($($fk.Columns -join ', ')) references $($fk.RefTable)")
                    }
                }
            }
        }
        $drifts.Add(@{
            kind             = 'table'
            change           = 'removed'
            element          = $tbl
            oldValue         = 'present'
            newValue         = 'absent'
            dependentObjects = @($dep)
        })
    }
}

# --- Added tables ---
foreach ($tbl in $newTableNames) {
    if ($tbl -notin $oldTableNames) {
        $drifts.Add(@{
            kind             = 'table'
            change           = 'added'
            element          = $tbl
            oldValue         = 'absent'
            newValue         = 'present'
            dependentObjects = @()
        })
    }
}

# --- Per-table diff for common tables ---
$commonTables = $oldTableNames | Where-Object { $_ -in $newTableNames }

foreach ($tbl in $commonTables) {
    $oldCols = $old.Tables[$tbl]
    $newCols = $new.Tables[$tbl]
    $oldColNames = @($oldCols | ForEach-Object { $_.Name })
    $newColNames = @($newCols | ForEach-Object { $_.Name })

    # --- Removed columns ---
    foreach ($col in $oldCols) {
        if ($col.Name -notin $newColNames) {
            $dep = [System.Collections.Generic.List[string]]::new()
            if ($old.Indexes.ContainsKey($tbl)) {
                foreach ($idx in $old.Indexes[$tbl]) {
                    if ($idx.Columns -contains $col.Name) {
                        $dep.Add("index $($idx.Name)")
                    }
                }
            }
            if ($old.ForeignKeys.ContainsKey($tbl)) {
                foreach ($fk in $old.ForeignKeys[$tbl]) {
                    if ($fk.Columns -contains $col.Name) {
                        $dep.Add("foreign key ($($fk.Columns -join ', ')) -> $($fk.RefTable)")
                    }
                }
            }
            $drifts.Add(@{
                kind             = 'column'
                change           = 'removed'
                element          = "$tbl.$($col.Name)"
                oldValue         = "$($col.Type) $(if(-not $col.Nullable){'NOT NULL'}else{'NULL'})$(if($col.Default){' '+$col.Default})"
                newValue         = 'absent'
                dependentObjects = @($dep)
            })
        }
    }

    # --- Added columns ---
    foreach ($col in $newCols) {
        if ($col.Name -notin $oldColNames) {
            $drifts.Add(@{
                kind             = 'column'
                change           = 'added'
                element          = "$tbl.$($col.Name)"
                oldValue         = 'absent'
                newValue         = "$($col.Type) $(if(-not $col.Nullable){'NOT NULL'}else{'NULL'})$(if($col.Default){' '+$col.Default})"
                dependentObjects = @()
            })
        }
    }

    # --- Modified columns ---
    foreach ($newCol in $newCols) {
        $oldCol = $oldCols | Where-Object { $_.Name -eq $newCol.Name } | Select-Object -First 1
        if ($null -eq $oldCol) { continue }

        if ($oldCol.Type -ne $newCol.Type) {
            $drifts.Add(@{
                kind             = 'column'
                change           = 'modified'
                element          = "$tbl.$($newCol.Name)"
                oldValue         = "type $($oldCol.Type)"
                newValue         = "type $($newCol.Type)"
                dependentObjects = @()
            })
        }

        if ($oldCol.Nullable -ne $newCol.Nullable) {
            $drifts.Add(@{
                kind             = 'column'
                change           = 'modified'
                element          = "$tbl.$($newCol.Name)"
                oldValue         = if($oldCol.Nullable){'nullable'}else{'not null'}
                newValue         = if($newCol.Nullable){'nullable'}else{'not null'}
                dependentObjects = @()
            })
        }

        $oldD = if ($oldCol.Default -ne $null) { $oldCol.Default.Trim() } else { $null }
        $newD = if ($newCol.Default -ne $null) { $newCol.Default.Trim() } else { $null }
        if ($oldD -ne $newD) {
            $drifts.Add(@{
                kind             = 'column'
                change           = 'modified'
                element          = "$tbl.$($newCol.Name)"
                oldValue         = "default $($oldCol.Default)"
                newValue         = "default $($newCol.Default)"
                dependentObjects = @()
            })
        }
    }

    # --- Index diff ---
    $oldIdxs = if ($old.Indexes.ContainsKey($tbl)) { @($old.Indexes[$tbl]) } else { @() }
    $newIdxs = if ($new.Indexes.ContainsKey($tbl)) { @($new.Indexes[$tbl]) } else { @() }
    $oldIdxNames = @($oldIdxs | ForEach-Object { $_.Name })
    $newIdxNames = @($newIdxs | ForEach-Object { $_.Name })

    foreach ($idx in $oldIdxs) {
        if ($idx.Name -notin $newIdxNames) {
            $drifts.Add(@{
                kind             = 'index'
                change           = 'removed'
                element          = "$tbl.$($idx.Name)"
                oldValue         = "($($idx.Columns -join ', '))"
                newValue         = 'absent'
                dependentObjects = @()
            })
        }
    }

    foreach ($idx in $newIdxs) {
        if ($idx.Name -notin $oldIdxNames) {
            $drifts.Add(@{
                kind             = 'index'
                change           = 'added'
                element          = "$tbl.$($idx.Name)"
                oldValue         = 'absent'
                newValue         = "($($idx.Columns -join ', '))"
                dependentObjects = @()
            })
        }
    }

    foreach ($newIdx in $newIdxs) {
        $oldIdx = $oldIdxs | Where-Object { $_.Name -eq $newIdx.Name } | Select-Object -First 1
        if ($null -eq $oldIdx) { continue }
        $oldC = $oldIdx.Columns -join ','
        $newC = $newIdx.Columns -join ','
        if ($oldC -ne $newC) {
            $drifts.Add(@{
                kind             = 'index'
                change           = 'modified'
                element          = "$tbl.$($newIdx.Name)"
                oldValue         = "($($oldIdx.Columns -join ', '))"
                newValue         = "($($newIdx.Columns -join ', '))"
                dependentObjects = @()
            })
        }
    }

    # --- FK diff ---
    $oldFks = if ($old.ForeignKeys.ContainsKey($tbl)) { @($old.ForeignKeys[$tbl]) } else { @() }
    $newFks = if ($new.ForeignKeys.ContainsKey($tbl)) { @($new.ForeignKeys[$tbl]) } else { @() }

    $oldFkKeys = $oldFks | ForEach-Object { "$($_.Columns -join '+')->$($_.RefTable)" }
    $newFkKeys = $newFks | ForEach-Object { "$($_.Columns -join '+')->$($_.RefTable)" }

    for ($i = 0; $i -lt $oldFks.Count; $i++) {
        if ($oldFkKeys[$i] -notin $newFkKeys) {
            $fk = $oldFks[$i]
            $drifts.Add(@{
                kind             = 'foreign key'
                change           = 'removed'
                element          = "$tbl.($($fk.Columns -join ', '))"
                oldValue         = "REFERENCES $($fk.RefTable)($($fk.RefColumns -join ', '))"
                newValue         = 'absent'
                dependentObjects = @()
            })
        }
    }

    for ($i = 0; $i -lt $newFks.Count; $i++) {
        if ($newFkKeys[$i] -notin $oldFkKeys) {
            $fk = $newFks[$i]
            $drifts.Add(@{
                kind             = 'foreign key'
                change           = 'added'
                element          = "$tbl.($($fk.Columns -join ', '))"
                oldValue         = 'absent'
                newValue         = "REFERENCES $($fk.RefTable)($($fk.RefColumns -join ', '))"
                dependentObjects = @()
            })
        }
    }
}

# ---------------------------------------------------------------
# Assemble output
# ---------------------------------------------------------------
$summary = @{
    totalDrifts       = $drifts.Count
    addedTables       = ($drifts | Where-Object { $_.kind -eq 'table' -and $_.change -eq 'added' }).Count
    removedTables     = ($drifts | Where-Object { $_.kind -eq 'table' -and $_.change -eq 'removed' }).Count
    addedColumns      = ($drifts | Where-Object { $_.kind -eq 'column' -and $_.change -eq 'added' }).Count
    removedColumns    = ($drifts | Where-Object { $_.kind -eq 'column' -and $_.change -eq 'removed' }).Count
    modifiedColumns  = ($drifts | Where-Object { $_.kind -eq 'column' -and $_.change -eq 'modified' }).Count
    addedIndexes      = ($drifts | Where-Object { $_.kind -eq 'index' -and $_.change -eq 'added' }).Count
    removedIndexes    = ($drifts | Where-Object { $_.kind -eq 'index' -and $_.change -eq 'removed' }).Count
    modifiedIndexes  = ($drifts | Where-Object { $_.kind -eq 'index' -and $_.change -eq 'modified' }).Count
    addedForeignKeys  = ($drifts | Where-Object { $_.kind -eq 'foreign key' -and $_.change -eq 'added' }).Count
    removedForeignKeys = ($drifts | Where-Object { $_.kind -eq 'foreign key' -and $_.change -eq 'removed' }).Count
}

$result = @{
    schemaDiff = @{
        oldSchema = $resolvedOld
        newSchema = $resolvedNew
        summary   = $summary
        drifts    = @($drifts)
    }
}

# ---------------------------------------------------------------
# Console output
# ---------------------------------------------------------------
Write-Host "`n=== SCHEMA DRIFT REPORT ===" -ForegroundColor Green
Write-Host "Total drifts: $($drifts.Count)" -ForegroundColor Yellow
$colorMap = @{
    'table'       = 'Red'
    'column'      = 'Yellow'
    'index'       = 'Magenta'
    'foreign key' = 'Cyan'
}
foreach ($d in $drifts) {
    $baseColor = $colorMap[$d.kind]
    $changeColor = if ($d.change -eq 'removed') { 'Red' } elseif ($d.change -eq 'added') { 'Green' } else { $baseColor }
    Write-Host "  [$($d.kind)] $($d.change): $($d.element)" -ForegroundColor $changeColor
    if ($d.oldValue -ne 'absent' -or $d.newValue -ne 'present') {
        Write-Host "    Old: $($d.oldValue)" -ForegroundColor DarkGray
        Write-Host "    New: $($d.newValue)" -ForegroundColor DarkGray
    }
    if ($d.dependentObjects -and $d.dependentObjects.Count -gt 0) {
        Write-Host "    Depends on: $($d.dependentObjects -join ', ')" -ForegroundColor DarkGray
    }
}

Write-Host "`n--- RAW JSON ---" -ForegroundColor Cyan
$json = $result | ConvertTo-Json -Depth 5
$json

exit 0
