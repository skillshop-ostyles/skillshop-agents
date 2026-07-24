[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Extensions = @('js', 'ts', 'py', 'rb', 'java', 'go', 'cs', 'php'),
    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage', '__pycache__', 'bin', 'obj')
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir does not exist: $ProjectDir"
    exit 1
}

$root = (Resolve-Path -LiteralPath $ProjectDir).Path
$excludeSet = @($Exclude | ForEach-Object { $_.ToLower() })
$extSet = @($Extensions | ForEach-Object { $_.TrimStart('.').ToLower() })
$schema = @{}
$mismatches = New-Object System.Collections.Generic.List[object]
$counts = @{ total = 0; critical = 0; major = 0; minor = 0; info = 0 }
$seenQueries = @{}

# ============================================================
# FUNCTION DEFINITIONS
# ============================================================

function Test-ExcludedPath($fullPath) {
    $rel = $fullPath.Substring($root.Length).TrimStart('\', '/')
    foreach ($part in ($rel -split '[\\/]')) {
        if ($excludeSet -contains $part.ToLower()) { return $true }
    }
    return $false
}

function Parse-CreateTable($tableName, $block) {
    $parenStart = $block.IndexOf('(')
    $parenEnd = $block.LastIndexOf(')')
    if ($parenStart -lt 0 -or $parenEnd -lt 0) { return }

    $colSection = $block.Substring($parenStart + 1, $parenEnd - $parenStart - 1)

    $cols = @()
    $depth = 0
    $current = ''
    foreach ($ch in $colSection.ToCharArray()) {
        if ($ch -eq '(') { $depth++ }
        elseif ($ch -eq ')') { $depth-- }
        elseif ($ch -eq ',' -and $depth -eq 0) {
            $cols += $current.Trim()
            $current = ''
            continue
        }
        $current += $ch
    }
    if ($current.Trim()) { $cols += $current.Trim() }

    if (-not $schema.ContainsKey($tableName)) {
        $schema[$tableName] = @{ columns = @{}; indexes = @() }
    }

    foreach ($colDef in $cols) {
        if ($colDef -match '(?i)^(PRIMARY\s+KEY|UNIQUE\s+(KEY|INDEX)|INDEX|KEY|FOREIGN\s+KEY|CONSTRAINT|CHECK)\b') {
            if ($colDef -match '(?i)^PRIMARY\s+KEY\s*\((\w+)\)') {
                $pkCol = $Matches[1]
                if ($schema[$tableName].indexes -notcontains $pkCol) {
                    $schema[$tableName].indexes += $pkCol
                }
            }
            continue
        }

        if ($colDef -match '(?i)^(?:`|"|\[)?(\w+)(?:`|"|\])?\s+(\w+(?:\s*\([^)]*\))?)\s*(.*)') {
            $colName = $Matches[1]
            $colType = $Matches[2]
            $rest = $Matches[3]
            $nullable = ($rest -notmatch '(?i)\bNOT\s+NULL\b')
            $default = $null
            if ($rest -match '(?i)DEFAULT\s+(.+?)$') {
                $d = $Matches[1].Trim().Trim(',').Trim()
                if ($d) { $default = $d }
            }

            $schema[$tableName].columns[$colName] = @{
                type = $colType
                nullable = $nullable
                default = $default
            }

            if ($rest -match '(?i)\bPRIMARY\s+KEY\b') {
                if ($schema[$tableName].indexes -notcontains $colName) {
                    $schema[$tableName].indexes += $colName
                }
            }
        }
    }
}

function Add-Mismatch($relPath, $lineNum, $tableName, $colName, $sqlSnippet, $colExists, $colInfo, $isIndexed, $risk, $mismatchType) {
    $counts.total++
    $counts[$risk]++
    $mismatches.Add([ordered]@{
            query = [ordered]@{
                file       = $relPath
                line       = $lineNum
                table      = $tableName
                column     = $colName
                sqlSnippet = $sqlSnippet
            }
            schema = [ordered]@{
                exists   = $colExists
                type     = if ($colInfo) { $colInfo.type } else { $null }
                indexed  = $isIndexed
                nullable = if ($colInfo) { $colInfo.nullable } else { $null }
            }
            risk         = $risk
            mismatchType = $mismatchType
        })
}

function Check-Column($tableName, $colName, $relPath, $lineNum, $sql) {
    if (-not $schema.ContainsKey($tableName)) { return }
    $tblSchema = $schema[$tableName]
    $colExists = $tblSchema.columns.ContainsKey($colName)
    $colInfo = if ($colExists) { $tblSchema.columns[$colName] } else { $null }
    $isIndexed = $tblSchema.indexes -contains $colName

    $mismatchType = $null
    $risk = $null

    if (-not $colExists) {
        $mismatchType = 'missing-column'
        $risk = 'critical'
    } elseif (-not $isIndexed) {
        $mismatchType = 'missing-index'
        $risk = 'major'
    }

    if (-not $mismatchType) { return }

    $snippet = $sql
    if ($snippet.Length -gt 80) { $snippet = $snippet.Substring(0, 77) + '...' }

    Add-Mismatch $relPath $lineNum $tableName $colName $snippet $colExists $colInfo $isIndexed $risk $mismatchType
}

function Analyze-SqlString($sql, $relPath, $lineNum) {
    $sqlKeywords = @('WHERE', 'JOIN', 'ON', 'SET', 'ORDER', 'GROUP', 'HAVING', 'LIMIT', 'OFFSET', 'INNER', 'LEFT', 'RIGHT', 'FULL', 'CROSS', 'OUTER', 'AND', 'OR', 'NOT', 'IN', 'AS', 'FROM', 'INTO', 'UPDATE', 'DELETE')

    $tableAliases = @{}

    foreach ($m in [regex]::Matches($sql, '(?i)\bFROM\s+(?:`|"|\[)?(\w+)(?:`|"|\])?(?:\s+(\w+))?\b')) {
        $tbl = $m.Groups[1].Value
        $alias = $tbl
        if ($m.Groups[2].Success) {
            $candidate = $m.Groups[2].Value
            if ($sqlKeywords -notcontains $candidate.ToUpper()) { $alias = $candidate }
        }
        $tableAliases[$alias] = $tbl
    }
    foreach ($m in [regex]::Matches($sql, '(?i)\bJOIN\s+(?:`|"|\[)?(\w+)(?:`|"|\])?(?:\s+(\w+))?\b')) {
        $tbl = $m.Groups[1].Value
        $alias = $tbl
        if ($m.Groups[2].Success) {
            $candidate = $m.Groups[2].Value
            if ($sqlKeywords -notcontains $candidate.ToUpper()) { $alias = $candidate }
        }
        $tableAliases[$alias] = $tbl
    }

    if ($tableAliases.Count -eq 0) { return }

    # WHERE clause: col = ? or tbl.col = ?
    $whereMatch = [regex]::Match($sql, '(?i)\bWHERE\s+(.+)')
    if ($whereMatch.Success) {
        $whereClause = $whereMatch.Groups[1].Value
        foreach ($cm in [regex]::Matches($whereClause, '(?i)(?:(\w+)\.)?(\w+)\s*=\s*\?')) {
            $alias = if ($cm.Groups[1].Success) { $cm.Groups[1].Value } else { $null }
            $colName = $cm.Groups[2].Value
            $tableName = $null
            if ($alias -and $tableAliases.ContainsKey($alias)) {
                $tableName = $tableAliases[$alias]
            } elseif (-not $alias -and $tableAliases.Count -eq 1) {
                $tableName = ($tableAliases.Values | Select-Object -First 1)
            }
            if ($tableName) { Check-Column $tableName $colName $relPath $lineNum $sql }
        }
    }

    # JOIN ON clauses
    foreach ($jm in [regex]::Matches($sql, '(?i)ON\s+(?:(\w+)\.)?(\w+)\s*=\s*(?:(\w+)\.)?(\w+)')) {
        $leftAlias = if ($jm.Groups[1].Success) { $jm.Groups[1].Value } else { $null }
        $leftCol = $jm.Groups[2].Value
        $rightAlias = if ($jm.Groups[3].Success) { $jm.Groups[3].Value } else { $null }
        $rightCol = $jm.Groups[4].Value

        if ($leftAlias -and $tableAliases.ContainsKey($leftAlias)) {
            Check-Column $tableAliases[$leftAlias] $leftCol $relPath $lineNum $sql
        }
        if ($rightAlias -and $tableAliases.ContainsKey($rightAlias)) {
            Check-Column $tableAliases[$rightAlias] $rightCol $relPath $lineNum $sql
        }
    }
}

# ============================================================
# STEP 1: Parse schema from DDL files
# ============================================================

$allFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { -not (Test-ExcludedPath $_.FullName) }

foreach ($f in ($allFiles | Where-Object { $_.Extension -eq '.sql' })) {
    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }

    $inTable = $false
    $tableName = $null
    $blockLines = @()

    foreach ($rawLine in $lines) {
        $line = $rawLine.Trim()
        if (-not $line -or $line -match '^--') { continue }

        if ($line -match '(?i)^CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(?:`|"|\[)?(\w+)(?:`|"|\])?') {
            if ($inTable -and $tableName) { Parse-CreateTable $tableName ($blockLines -join ' ') }
            $tableName = $Matches[1]
            $inTable = $true
            $blockLines = @($line)
            if ($line -match '\);$') { Parse-CreateTable $tableName ($blockLines -join ' '); $inTable = $false }
            continue
        }

        if ($inTable) {
            $blockLines += $line
            if ($line -match '\);$') { Parse-CreateTable $tableName ($blockLines -join ' '); $inTable = $false }
        }

        if ($line -match '(?i)CREATE\s+(?:UNIQUE\s+)?INDEX\s+(?:\w+\s+)?ON\s+(?:`|"|\[)?(\w+)(?:`|"|\])?\s*\(([^)]+)\)') {
            $tbl = $Matches[1]
            $idxCols = $Matches[2] -split ',' | ForEach-Object { $_.Trim().Trim('`', '"', '[', ']', ' ') }
            if (-not $schema.ContainsKey($tbl)) { $schema[$tbl] = @{ columns = @{}; indexes = @() } }
            foreach ($ic in $idxCols) {
                if ($schema[$tbl].indexes -notcontains $ic) { $schema[$tbl].indexes += $ic }
            }
        }
    }

    if ($inTable -and $tableName) { Parse-CreateTable $tableName ($blockLines -join ' ') }
}

# --- 1b: Parse ORM model files ---

foreach ($f in ($allFiles | Where-Object { $_.Extension -in '.prisma', '.ts', '.js', '.py' })) {
    $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    if ($f.Extension -eq '.prisma') {
        foreach ($pm in [regex]::Matches($content, '(?i)model\s+(\w+)\s*\{([^}]+)\}')) {
            $tbl = $pm.Groups[1].Value; $fields = $pm.Groups[2].Value
            if (-not $schema.ContainsKey($tbl)) { $schema[$tbl] = @{ columns = @{}; indexes = @() } }
            foreach ($fm in [regex]::Matches($fields, '(?mi)^\s*(\w+)\s+(String|Int|Boolean|DateTime|Float|Json|BigInt|Bytes|Decimal)\b')) {
                $col = $fm.Groups[1].Value; $colType = $fm.Groups[2].Value; $colNullable = ($fields -match "(?i)$col\s+$colType\?")
                if (-not $schema[$tbl].columns.ContainsKey($col)) { $schema[$tbl].columns[$col] = @{ type = $colType; nullable = $colNullable; default = $null } }
            }
        }
    }

    foreach ($em in [regex]::Matches($content, '(?i)@Entity\([''"]?(\w+)[''"]?\)')) {
        $entityName = $em.Groups[1].Value
        if (-not $schema.ContainsKey($entityName)) { $schema[$entityName] = @{ columns = @{}; indexes = @() } }
    }
    foreach ($sm in [regex]::Matches($content, '(?i)sequelize\.define\([''"](\w+)[''"]')) {
        $modelName = $sm.Groups[1].Value
        if (-not $schema.ContainsKey($modelName)) { $schema[$modelName] = @{ columns = @{}; indexes = @() } }
    }
    foreach ($pm in [regex]::Matches($content, '(?i)prisma\.(\w+)\.\w+\(')) {
        $modelName = $pm.Groups[1].Value
        if (-not $schema.ContainsKey($modelName)) { $schema[$modelName] = @{ columns = @{}; indexes = @() } }
    }
}

# ============================================================
# STEP 2: Scan source files for query patterns
# ============================================================

foreach ($f in ($allFiles | Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() })) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    # --- Tagged template literals: sql`...`, query`...` ---
    $taggedPats = @(
        '(?i)(?:sql|query|raw|execute)\s*`((?:[^`\\]|\\.)*)`'
    )
    foreach ($pat in $taggedPats) {
        foreach ($m in [regex]::Matches($content, $pat)) {
            $inner = $m.Groups[1].Value
            if ($inner -match '(?i)\b(SELECT\s|INSERT\s+INTO|UPDATE\s|DELETE\s+FROM)') {
                $lineNum = ($content.Substring(0, $m.Index) -split "`n").Length
                $key = "${relPath}:${lineNum}:$($inner.GetHashCode())"
                if ($seenQueries.ContainsKey($key)) { continue }
                $seenQueries[$key] = $true; Analyze-SqlString $inner $relPath $lineNum
            }
        }
    }

    # --- Method calls: .query(), .execute(), .raw() ---
    $methodPats = @(
        '(?i)\.query\s*\(\s*"((?:[^"\\]|\\.)*)"',
        "(?i)\.query\s*\(\s*'((?:[^'\\]|\\.)*)'",
        '(?i)\.query\s*\(\s*`((?:[^`\\]|\\.)*)`',
        '(?i)\.execute\s*\(\s*"((?:[^"\\]|\\.)*)"',
        "(?i)\.execute\s*\(\s*'((?:[^'\\]|\\.)*)'",
        '(?i)\.execute\s*\(\s*`((?:[^`\\]|\\.)*)`',
        '(?i)\.raw\s*\(\s*"((?:[^"\\]|\\.)*)"',
        "(?i)\.raw\s*\(\s*'((?:[^'\\]|\\.)*)'",
        '(?i)\.raw\s*\(\s*`((?:[^`\\]|\\.)*)`',
        '(?i)(?:db|pool|client|conn)\.\s*query\s*\(\s*"((?:[^"\\]|\\.)*)"',
        "(?i)(?:db|pool|client|conn)\.\s*query\s*\(\s*'((?:[^'\\]|\\.)*)'",
        '(?i)(?:db|pool|client|conn)\.\s*query\s*\(\s*`((?:[^`\\]|\\.)*)`'
    )
    foreach ($pat in $methodPats) {
        foreach ($m in [regex]::Matches($content, $pat)) {
            $inner = $m.Groups[1].Value
            if ($inner -match '(?i)\b(SELECT\s|INSERT\s+INTO|UPDATE\s|DELETE\s+FROM)') {
                $lineNum = ($content.Substring(0, $m.Index) -split "`n").Length
                $key = "${relPath}:${lineNum}:$($inner.GetHashCode())"
                if ($seenQueries.ContainsKey($key)) { continue }
                $seenQueries[$key] = $true; Analyze-SqlString $inner $relPath $lineNum
            }
        }
    }

    # ORM-style: Model.findOne({where: {field: val}})
    foreach ($m in [regex]::Matches($content, '(?i)(\w+)\.(?:findOne|findAll|find)\s*\(\s*\{[^}]*where\s*:\s*\{([^}]*)\}')) {
        $modelName = $m.Groups[1].Value; $whereFields = $m.Groups[2].Value
        $lineNum = ($content.Substring(0, $m.Index) -split "`n").Length
        $tableName = ($modelName -creplace '([a-z])([A-Z])', '$1_$2').ToLower()
        if (-not $schema.ContainsKey($tableName)) { $tableName = $modelName.ToLower() }
        foreach ($fm in [regex]::Matches($whereFields, '(?i)(\w+)\s*:')) {
            $ormCol = $fm.Groups[1].Value
            Check-Column $tableName $ormCol $relPath $lineNum ("ORM " + $modelName + ".findOne(where: {" + $ormCol + "})")
        }
    }
}

# ============================================================
# OUTPUT
# ============================================================

$result = [ordered]@{
    mismatches = $mismatches.ToArray()
    counts     = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== QUERY-SCHEMA-DIFF ==="
Write-Output "  Project    : $root"
Write-Output "  Files      : $($allFiles.Count)"
Write-Output "  Mismatches : $($counts.total)"
Write-Output "    critical : $($counts.critical)"
Write-Output "    major    : $($counts.major)"
Write-Output "    minor    : $($counts.minor)"
Write-Output "    info     : $($counts.info)"
