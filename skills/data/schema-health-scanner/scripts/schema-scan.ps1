[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.sql,*.prisma",
    [string]$Exclude = ""
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

# Parse a CREATE TABLE statement into a table object.
function Parse-CreateTable($statement, $file) {
    $lines = $statement -split "`r`n|`n"

    # Extract table name: CREATE TABLE [IF NOT EXISTS] <name> (
    $tableName = $null
    $header = $lines[0]
    $m = [regex]::Match($header, 'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:`?(\w+)`?\.)?`?(\w+)`?\s*\(')
    if ($m.Success) {
        $tableName = $m.Groups[2].Value
    } else {
        return $null
    }

    $columns = @()
    $pk = $null
    $fk = @()
    $indexes = @()
    $uniques = @()

    # Process each line inside parentheses (skip header and trailing closing paren).
    $inBody = $false
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^CREATE\s+TABLE') { $inBody = $true; continue }
        if (-not $inBody) { continue }
        if ($trimmed -eq ')' -or $trimmed -eq ');') { break }

        # Remove trailing comma
        if ($trimmed.EndsWith(',')) { $trimmed = $trimmed.Substring(0, $trimmed.Length - 1) }

        # Skip empty and comment lines
        if (-not $trimmed -or $trimmed.StartsWith('--') -or $trimmed.StartsWith('#')) { continue }

        # Column definition: name type [NOT NULL] [DEFAULT ...] [constraints...]
        $colMatch = [regex]::Match($trimmed, '^`?(\w+)`?\s+(\w+(?:\s*\(\s*\d+(?:\s*,\s*\d+)?\s*\))?(?:\s+\w+)*)')
        if ($colMatch.Success) {
            $colName = $colMatch.Groups[1].Value
            $colTypeRaw = $colMatch.Groups[2].Value.Trim()

            # Normalize type (strip extra spaces, lowercase base)
            $baseType = $colTypeRaw -replace '\s+', ' '
            $baseType = $baseType -replace '\(\s*(\d+)\s*\)', '($1)'

            $notNull = $trimmed -match '\bNOT\s+NULL\b'
            $default = $null
            $dfltM = [regex]::Match($trimmed, '\bDEFAULT\s+(.+?)(?:\s+(?:NOT\s+NULL|UNIQUE|REFERENCES|PRIMARY\s+KEY|CHECK)\s*|$)')
            if ($dfltM.Success) { $default = $dfltM.Groups[1].Value.Trim() }

            $isPk = $trimmed -match '\bPRIMARY\s+KEY\b'
            $isUnique = $trimmed -match '\bUNIQUE\b'

            # Inline FK: REFERENCES other_table(other_col)
            $fkMatch = [regex]::Match($trimmed, 'REFERENCES\s+`?(\w+)`?\s*\(\s*`?(\w+)`?\s*\)')
            $fkRef = if ($fkMatch.Success) { @{ table = $fkMatch.Groups[1].Value; column = $fkMatch.Groups[2].Value } } else { $null }

            $colType = ($baseType -split '\s+')[0].ToLower()

            $colObj = @{
                name = $colName
                type = $baseType
                nullable = (-not $notNull)
                default = $default
                isPrimaryKey = $isPk
                isUnique = $isUnique
                foreignKey = $fkRef
            }
            $columns += $colObj
            if ($isPk) { $pk = @($colName) }
            if ($fkRef) { $fk += @{ column = $colName; references = $fkRef } }
            continue
        }

        # Table-level PRIMARY KEY (col1, col2)
        $pkMatch = [regex]::Match($trimmed, '^PRIMARY\s+KEY\s*\(\s*`?(\w+)`?\s*(?:,\s*`?(\w+)`?\s*)*\)')
        if ($pkMatch.Success) {
            $pkCols = [regex]::Matches($trimmed, '`?(\w+)`?') | ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -ne 'PRIMARY' -and $_ -ne 'KEY' }
            $pk = @($pkCols)
            continue
        }

        # Table-level FOREIGN KEY
        $fkMatch2 = [regex]::Match($trimmed, '^FOREIGN\s+KEY\s*\(\s*`?(\w+)`?\s*\)\s*REFERENCES\s+`?(\w+)`?\s*\(\s*`?(\w+)`?\s*\)')
        if ($fkMatch2.Success) {
            $fkCol = $fkMatch2.Groups[1].Value
            $refTable = $fkMatch2.Groups[2].Value
            $refCol = $fkMatch2.Groups[3].Value
            $fk += @{ column = $fkCol; references = @{ table = $refTable; column = $refCol } }
            continue
        }

        # INDEX (non-unique)
        $idxMatch = [regex]::Match($trimmed, '^(?:CREATE\s+)?(?:UNIQUE\s+)?(?:INDEX\s+`?\w+`?\s+ON\s+)?`?(\w+)`?\s*\(\s*`?(\w+)`?\s*\)')
        # Simplified: detect "INDEX" keyword or "KEY" keyword standalone
        $idxLine = [regex]::Match($trimmed, '^(?:UNIQUE\s+)?(?:INDEX|KEY)\s+`?(\w+)`?\s*\(\s*`?(\w+)`?\s*\)')
        if ($idxLine.Success) {
            $idxName = $idxLine.Groups[1].Value
            $idxCol = $idxLine.Groups[2].Value
            $isUniqueIdx = $trimmed -match '^UNIQUE'
            $indexObj = @{ name = $idxName; columns = @($idxCol); unique = $isUniqueIdx }
            $indexes += $indexObj
            if ($isUniqueIdx) { $uniques += $idxCol }
            continue
        }

        # Standalone UNIQUE constraint: UNIQUE KEY/INDEX or CONSTRAINT ... UNIQUE
        $uniMatch = [regex]::Match($trimmed, '^UNIQUE\s+(?:KEY|INDEX)?\s*`?(\w+)`?\s*\(\s*`?(\w+)`?\s*\)')
        if ($uniMatch.Success) {
            $uCol = $uniMatch.Groups[2].Value
            $uniques += $uCol
            $indexes += @{ name = $uniMatch.Groups[1].Value; columns = @($uCol); unique = $true }
            continue
        }
    }

    # If no PK found, check for a single non-nullable unique column as surrogate.
    if (-not $pk) {
        $unnullableUnique = $columns | Where-Object { (-not $_.nullable) -and $_.isUnique } | Select-Object -First 1
        if ($unnullableUnique) { $pk = @($unnullableUnique.name) }
    }

    return @{
        name = $tableName
        file = $file
        columns = $columns
        pk = $pk
        fk = $fk
        indexes = $indexes
        uniques = $uniques
    }
}

$extList = $Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
$tables = @()
$scannedFiles = 0

function Get-NamingStyle($columns) {
    $camel = 0; $snake = 0; $pascal = 0
    foreach ($col in $columns) {
        $name = $col.name
        if ($name -match '_') {
            if ($name -cmatch '^[a-z]+_[a-z]') { $snake++ }
            else { $pascal++ }
        } elseif ($name -cmatch '^[a-z]+[A-Z]') { $camel++ }
        elseif ($name -cmatch '^[A-Z][a-z]') { $pascal++ }
        elseif ($name -cmatch '^[A-Z]+$' -and $name.Length -gt 1) { $pascal++ }
        # Single-word lowercase (id, email) = neutral, skip
    }
    $total = $camel + $snake + $pascal
    if ($total -eq 0) { return 'unknown' }
    $nonZero = @($camel, $snake, $pascal | Where-Object { $_ -gt 0 }).Count
    if ($nonZero -ge 2) { return 'mixed' }
    if ($camel -gt 0) { return 'camelCase' }
    if ($snake -gt 0) { return 'snake_case' }
    return 'PascalCase'
}

function Get-TypeConsistency($columns) {
    $timestampTypes = @('timestamp', 'timestamptz', 'datetime', 'timestamp without time zone', 'timestamp with time zone')
    $stringTypes = @('varchar', 'char', 'text', 'nvarchar', 'nchar', 'character varying', 'character')
    $intTypes = @('int', 'integer', 'bigint', 'smallint', 'tinyint', 'serial', 'bigserial', 'smallserial')

    $tsCount = 0; $strCount = 0; $intCount = 0; $otherCount = 0
    foreach ($col in $columns) {
        $base = ($col.type -split '\s+')[0].ToLower()
        if ($base -in $timestampTypes) { $tsCount++ }
        elseif ($base -in $stringTypes) { $strCount++ }
        elseif ($base -in $intTypes) { $intCount++ }
        else { $otherCount++ }
    }
    return @{
        timestampCount = $tsCount
        stringCount = $strCount
        intCount = $intCount
        otherCount = $otherCount
    }
}

function Get-AntiPatterns($table) {
    $aps = @()
    $cols = $table.columns
    $name = $table.name

    # Missing primary key
    if (-not $table.pk -or $table.pk.Count -eq 0) {
        $aps += @{ pattern = 'missing-primary-key'; severity = 'high'; detail = "Table '$name' has no primary key" }
    }

    # FK without index
    foreach ($fk in $table.fk) {
        $indexed = ($table.indexes | Where-Object { $_.columns -contains $fk.column }) -or ($table.pk -contains $fk.column)
        $uniqueCol = ($table.uniques -contains $fk.column)
        if (-not $indexed -and -not $uniqueCol) {
            $aps += @{ pattern = 'fk-without-index'; severity = 'medium'; detail = "Foreign key column '$($fk.column)' has no index" }
        }
    }

    # Naming inconsistency (mixed styles across columns)
    $style = Get-NamingStyle $cols
    if ($style -eq 'mixed') {
        $aps += @{ pattern = 'mixed-naming-convention'; severity = 'low'; detail = "Table '$name' uses mixed naming conventions (camelCase and snake_case)" }
    }

    # God table (more than 20 columns)
    if ($cols.Count -gt 20) {
        $aps += @{ pattern = 'god-table'; severity = 'medium'; detail = "Table '$name' has $($cols.Count) columns - possible god table" }
    }

    # Missing timestamps
    $tsTypes = @('timestamp', 'timestamptz', 'datetime', 'timestamp with time zone', 'timestamp without time zone', 'datetime2')
    $hasTimestamp = ($cols | Where-Object { ($_.type -split '\s+')[0].ToLower() -in $tsTypes }).Count -gt 0
    if (-not $hasTimestamp) {
        $aps += @{ pattern = 'missing-timestamps'; severity = 'low'; detail = "Table '$name' has no timestamp column" }
    }

    # Unbounded strings (VARCHAR without length or TEXT where VARCHAR(n) would suffice)
    $unbounded = $cols | Where-Object {
        $base = ($_.type -split '\s+')[0].ToLower()
        $base -eq 'text' -or $base -eq 'nvarchar(max)' -or $base -eq 'varchar(max)' -or
        ($base -eq 'varchar' -and $_.type -notmatch '\(\d+\)')
    }
    if ($unbounded.Count -gt 0) {
        $aps += @{ pattern = 'unbounded-string-columns'; severity = 'low'; detail = "Table '$name' has $($unbounded.Count) unbounded string column(s): $($unbounded.Name -join ', ')" }
    }

    return $aps
}

foreach ($ext in $extList) {
    Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch 'node_modules|\.git|venv|bin|obj|__pycache__|dist|build'
    } | ForEach-Object {
        $fp = $_.FullName
        $scannedFiles++
        $content = Get-Content -LiteralPath $fp -Raw -ErrorAction SilentlyContinue
        if (-not $content) { return }

        $rel = $fp.Substring($ProjectDir.Length).TrimStart('\')

        # Split into individual CREATE TABLE statements (handle multi-statement files)
        $statements = $content -split '(?=CREATE\s+TABLE\s+)' | Where-Object { $_ -match 'CREATE\s+TABLE' }
        if (-not $statements) {
            # Try finding CREATE TABLE at any position
            $pos = 0
            while ($true) {
                $idx = $content.IndexOf('CREATE TABLE', $pos, [StringComparison]::OrdinalIgnoreCase)
                if ($idx -lt 0) { break }
                # Find the matching closing paren for this statement
                $startParen = $content.IndexOf('(', $idx)
                if ($startParen -lt 0) { $pos = $idx + 12; continue }
                $depth = 0; $endPos = $startParen
                for ($i = $startParen; $i -lt $content.Length; $i++) {
                    if ($content[$i] -eq '(') { $depth++ }
                    elseif ($content[$i] -eq ')') {
                        $depth--
                        if ($depth -eq 0) { $endPos = $i; break }
                    }
                }
                $stmt = $content.Substring($idx, $endPos - $idx + 1)
                $statements += @($stmt)
                $pos = $endPos + 1
            }
        }

        # Collect standalone CREATE INDEX statements for post-processing
        $standaloneIndexes = @{}
        $idxMatches = [regex]::Matches($content, 'CREATE\s+(?:UNIQUE\s+)?INDEX\s+(?:IF\s+NOT\s+EXISTS\s+)?`?(\w+)`?\s+ON\s+`?(\w+)`?\s*\(\s*`?(\w+)`?\s*\)', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        foreach ($idxMatch in $idxMatches) {
            $idxName = $idxMatch.Groups[1].Value
            $idxTable = $idxMatch.Groups[2].Value
            $idxCol = $idxMatch.Groups[3].Value
            $isUnique = $content.Substring(0, $idxMatch.Index) -match 'UNIQUE' -or $false
            if (-not $standaloneIndexes.ContainsKey($idxTable)) {
                $standaloneIndexes[$idxTable] = @()
            }
            $standaloneIndexes[$idxTable] += @{ name = $idxName; columns = @($idxCol); unique = $isUnique }
        }

        foreach ($stmt in $statements) {
            $table = Parse-CreateTable $stmt $rel
            if ($table) {
                # Attach standalone indexes for this table
                if ($standaloneIndexes.ContainsKey($table.name)) {
                    $table.indexes += $standaloneIndexes[$table.name]
                }
                $metrics = @{
                    fieldCount = $table.columns.Count
                    namingStyle = Get-NamingStyle $table.columns
                    typeConsistency = Get-TypeConsistency $table.columns
                    hasTimestamps = ($table.columns | Where-Object {
                        $base = ($_.type -split '\s+')[0].ToLower()
                        $base -in @('timestamp', 'timestamptz', 'datetime', 'timestamp with time zone', 'timestamp without time zone', 'datetime2')
                    }).Count -gt 0
                    fkIndexCoverage = if ($table.fk.Count -gt 0) {
                        $covered = 0
                        foreach ($fk in $table.fk) {
                            $isIndexed = ($table.indexes | Where-Object { $_.columns -contains $fk.column }).Count -gt 0 -or ($table.pk -contains $fk.column)
                            if ($isIndexed) { $covered++ }
                        }
                        [math]::Round($covered / $table.fk.Count * 100, 0)
                    } else { 100 }
                }
                $aps = @(Get-AntiPatterns $table)
                $tables += @{
                    name = $table.name
                    file = $table.file
                    columns = $table.columns
                    pk = $table.pk
                    fk = $table.fk
                    indexes = $table.indexes
                    uniques = $table.uniques
                    metrics = $metrics
                    antiPatterns = $aps
                }
            }
        }
    }
}

$totalAntiPatterns = ($tables | ForEach-Object { $_.antiPatterns.Count }) | Measure-Object -Sum | ForEach-Object Sum

$result = @{
    tables = $tables
    counts = @{
        scannedFiles = $scannedFiles
        tables = $tables.Count
        antiPatterns = if ($totalAntiPatterns) { $totalAntiPatterns } else { 0 }
    }
}

$json = $result | ConvertTo-Json -Depth 5
Write-Output $json

Write-Output ""
Write-Output "=== Schema Scan Complete ==="
Write-Output "  Files scanned: $scannedFiles"
Write-Output "  Tables found: $($tables.Count)"
Write-Output "  Anti-patterns detected: $(if ($totalAntiPatterns) { $totalAntiPatterns } else { 0 })"
foreach ($t in $tables) {
    Write-Output "  Table '$($t.name)': $($t.columns.Count) columns, $($t.antiPatterns.Count) anti-pattern(s)"
}
exit 0
