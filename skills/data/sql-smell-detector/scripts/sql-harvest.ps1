[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.js,*.ts,*.py,*.rb,*.java,*.go,*.cs"
)

$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

$ErrorActionPreference = "Stop"
$PSDefaultParameterValues['Out-File:Encoding'] = 'utf8'
$OutputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

$extList = $Extensions -split ',' | ForEach-Object { $_.Trim() }

function Get-SourceFiles {
    param([string]$Dir)
    $files = @()
    foreach ($ext in $extList) {
        $found = Get-ChildItem -Path $Dir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue
        foreach ($f in $found) {
            if ($f.FullName -notlike "*\node_modules\*" -and $f.FullName -notlike "*\.git\*" -and $f.FullName -notlike "*\venv\*" -and $f.FullName -notlike "*\__pycache__\*" -and $f.FullName -notlike "*\.next\*" -and $f.FullName -notlike "*\dist\*") {
                $files += $f
            }
        }
    }
    return $files
}

$sqlKeywordPattern = '(?i)(SELECT\s+|INSERT\s+INTO\s+|UPDATE\s+|DELETE\s+FROM\s+|MERGE\s+INTO\s+)'

function Find-StringLiterals {
    param([string]$Content)
    $results = @()

    # Double-quoted strings
    $dqMatches = [regex]::Matches($Content, '"((?:[^"\\]|\\.)*)"')
    foreach ($m in $dqMatches) {
        $inner = $m.Groups[1].Value
        if ($inner -match $sqlKeywordPattern) {
            $lineNum = ($Content.Substring(0, $m.Index) -split "`n").Length
            $results += @{ sql = $inner; line = $lineNum; index = $m.Index }
        }
    }

    # Single-quoted strings
    $sqMatches = [regex]::Matches($Content, "'((?:[^'\\]|\\.)*)'")
    foreach ($m in $sqMatches) {
        $inner = $m.Groups[1].Value
        if ($inner -match $sqlKeywordPattern) {
            $lineNum = ($Content.Substring(0, $m.Index) -split "`n").Length
            $results += @{ sql = $inner; line = $lineNum; index = $m.Index }
        }
    }

    # Backtick template literals (tagged or plain)
    $btMatches = [regex]::Matches($Content, '`((?:[^`\\]|\\.)*)`')
    foreach ($m in $btMatches) {
        $inner = $m.Groups[1].Value
        if ($inner -match $sqlKeywordPattern) {
            $lineNum = ($Content.Substring(0, $m.Index) -split "`n").Length
            $results += @{ sql = $inner; line = $lineNum; index = $m.Index }
        }
    }

    # Tagged template literals: sql`...`, query`...`, etc.
    $tagMatches = [regex]::Matches($Content, '(?i)(sql|query|raw|execute|db)\s*`((?:[^`\\]|\\.)*)`')
    foreach ($m in $tagMatches) {
        $inner = $m.Groups[2].Value
        if ($inner -match $sqlKeywordPattern) {
            $lineNum = ($Content.Substring(0, $m.Index) -split "`n").Length
            $results += @{ sql = $inner; line = $lineNum; index = $m.Index }
        }
    }

    # Raw SQL method calls: .query("..."), .execute('...'), .raw(`...`), db.run("...")
    $methodPatterns = @(
        '(?i)\.query\s*\(\s*"((?:[^"\\]|\\.)*)"\s*\)',
        '(?i)\.query\s*\(\s*''((?:[^''\\]|\\.)*)''\s*\)',
        '(?i)\.query\s*\(\s*`((?:[^`\\]|\\.)*)`\s*\)',
        '(?i)\.execute\s*\(\s*"((?:[^"\\]|\\.)*)"\s*\)',
        '(?i)\.execute\s*\(\s*''((?:[^''\\]|\\.)*)''\s*\)',
        '(?i)\.execute\s*\(\s*`((?:[^`\\]|\\.)*)`\s*\)',
        '(?i)\.raw\s*\(\s*"((?:[^"\\]|\\.)*)"\s*\)',
        '(?i)\.raw\s*\(\s*''((?:[^''\\]|\\.)*)''\s*\)',
        '(?i)\.raw\s*\(\s*`((?:[^`\\]|\\.)*)`\s*\)',
        '(?i)(?:db|conn|pool|client)\.run\s*\(\s*"((?:[^"\\]|\\.)*)"\s*\)',
        '(?i)(?:db|conn|pool|client)\.run\s*\(\s*''((?:[^''\\]|\\.)*)''\s*\)',
        '(?i)(?:db|conn|pool|client)\.run\s*\(\s*`((?:[^`\\]|\\.)*)`\s*\)'
    )
    foreach ($pat in $methodPatterns) {
        $methodMatches = [regex]::Matches($Content, $pat)
        foreach ($m in $methodMatches) {
            $inner = $m.Groups[1].Value
            if ($inner -match $sqlKeywordPattern) {
                $lineNum = ($Content.Substring(0, $m.Index) -split "`n").Length
                $results += @{ sql = $inner; line = $lineNum; index = $m.Index }
            }
        }
    }

    return $results
}
$numericColumnPattern = '(?i)\b(id|count|price|amount|total|year|age|score|rank|quantity|rating|version|priority|balance|cost|fee|tax|discount|shipping|weight|height|width|length)\b'

$stringColumnPattern = '(?i)\b(name|email|address|description|title|code|status|type|category|comment|note|summary|body|message|password|hash|token|slug|url|path|filename|color|gender|language|currency|timezone|phone|zip|zip_code)\b'

function Get-AntiPatterns {
    param([string]$Sql)
    $findings = @()

    # 1. SELECT * without explicit column list
    if ($Sql -match '(?i)\bSELECT\s+\*(?:\s+FROM\s+\(\s*SELECT)?') {
        # Exclude subquery patterns (SELECT * FROM (SELECT ...))
        if ($Matches[0] -notmatch 'SELECT\s+\*\s+FROM\s+\(') {
            $findings += @{
                rule = "select-star"
                severity = "medium"
                detail = "SELECT * retrieves all columns; explicit column list improves performance and maintainability"
            }
        }
    }

    # 2. Missing WHERE on SELECT/DELETE/UPDATE
    if ($Sql -match '(?i)\b(SELECT\s+.*?\s+FROM|DELETE\s+FROM|UPDATE\s+)') {
        $stmtType = $Matches[1]
        $hasWhere = $Sql -match '(?i)\bWHERE\b'
        $hasLimit = $Sql -match '(?i)\bLIMIT\b'
        $hasTop = $Sql -match '(?i)\bTOP\b'
        if (-not $hasWhere -and -not $hasLimit -and -not $hasTop -and $stmtType -notmatch '(?i)^SELECT\s+.*?\s+FROM\s+\(') {
            $severity = if ($Sql -match '(?i)^\s*(DELETE|UPDATE)\s') { "critical" } else { "high" }
            $findings += @{
                rule = "missing-where"
                severity = $severity
                detail = "No WHERE clause found in $stmtType - this may scan the entire table"
            }
        }
    }

    # 3. Non-sargable: function(column) = value
    $nsMatches = [regex]::Matches($Sql, '(?i)\bWHERE\s+.*?(\w+)\s*\((\w+)\)\s*=\s*')
    foreach ($m in $nsMatches) {
        $findings += @{
            rule = "non-sargable-function-wrap"
            severity = "high"
            detail = "Function '$($m.Groups[1].Value)($($m.Groups[2].Value))' in WHERE prevents index usage; consider computed column or index on expression"
        }
    }

    # 4. Non-sargable: LIKE with leading wildcard
    if ($Sql -match '(?i)\bLIKE\s+[''"]%') {
        $findings += @{
            rule = "non-sargable-like-wildcard"
            severity = "high"
            detail = "LIKE with leading wildcard '%...' prevents index usage; consider full-text search or reverse LIKE"
        }
    }

    # 5. Non-sargable: LIKE with single-char wildcard prefix
    if ($Sql -match '(?i)\bLIKE\s+[''"]_') {
        $findings += @{
            rule = "non-sargable-like-underscore"
            severity = "medium"
            detail = "LIKE with leading underscore '_...' prevents index usage"
        }
    }

    # 6. SELECT DISTINCT on multi-table JOINs without aggregation
    if ($Sql -match '(?i)\bSELECT\s+DISTINCT\b') {
        $hasJoin = $Sql -match '(?i)\bJOIN\b'
        $hasAggregate = $Sql -match '(?i)\b(COUNT|SUM|AVG|MAX|MIN|GROUP\s+BY)\b'
        if ($hasJoin -and -not $hasAggregate) {
            $findings += @{
                rule = "distinct-join-without-aggregate"
                severity = "medium"
                detail = "SELECT DISTINCT with JOIN but no aggregation - DISTINCT may be masking a duplicate-producing JOIN; consider refining JOIN conditions"
            }
        }
    }

    # 7. Unanchored LIKE (starting with %)
    if ($Sql -match '(?i)\bLIKE\s+[''"]%') {
        $findings += @{
            rule = "unanchored-like"
            severity = "low"
            detail = "LIKE pattern starts with wildcard '%' - cannot use index for prefix search"
        }
    }

    # 8. Implicit cast in WHERE (heuristic)
    # Pattern: WHERE column = unquoted_number where column is likely varchar
    $icMatches1 = [regex]::Matches($Sql, '(?i)\bWHERE\s+.*?(\w+)\s*=\s*(\d+)\b(?!\s*\))')
    foreach ($m in $icMatches1) {
        $colName = $m.Groups[1].Value
        if ($colName -match $stringColumnPattern) {
            $findings += @{
                rule = "implicit-cast"
                severity = "medium"
                detail = "Column '$colName' (likely varchar) compared to numeric literal $($m.Groups[2].Value) - implicit cast may prevent index usage"
            }
        }
    }
    # Pattern: WHERE column = 'string' where column is likely numeric
    $icMatches2 = [regex]::Matches($Sql, '(?i)\bWHERE\s+.*?(\w+)\s*=\s*''([^'']+)''')
    foreach ($m in $icMatches2) {
        $colName = $m.Groups[1].Value
        $literal = $m.Groups[2].Value
        if ($colName -match $numericColumnPattern -and $literal -match '^\d+$') {
            $findings += @{
                rule = "implicit-cast"
                severity = "medium"
                detail = "Column '$colName' (likely numeric) compared to string literal '$literal' - implicit cast may prevent index usage"
            }
        }
    }

    # 9. Cartesian product: two FROM tables without JOIN or WHERE
    $fromTables = [regex]::Matches($Sql, '(?i)\bFROM\s+(\w+(?:\s+\w+)?(?:\s*,\s*\w+(?:\s+\w+)?)+)')
    foreach ($m in $fromTables) {
        $tablesStr = $m.Groups[1].Value
        $tables = $tablesStr -split ',' | ForEach-Object { $_.Trim() }
        if ($tables.Count -ge 2) {
            $hasJoin = $Sql -match '(?i)\bJOIN\b'
            $hasWhere = $Sql -match '(?i)\bWHERE\b'
            if (-not $hasJoin -and -not $hasWhere) {
                $findings += @{
                    rule = "cartesian-product"
                    severity = "critical"
                    detail = "Implicit cartesian product: $($tables.Count) tables in FROM without JOIN or WHERE clause"
                }
            }
        }
    }

    # 10. SELECT DISTINCT without JOIN (usually unnecessary)
    if ($Sql -match '(?i)\bSELECT\s+DISTINCT\b') {
        $hasJoin = $Sql -match '(?i)\bJOIN\b'
        $hasAggregate = $Sql -match '(?i)\b(COUNT|SUM|AVG|MAX|MIN|GROUP\s+BY)\b'
        if (-not $hasJoin -and -not $hasAggregate) {
            $findings += @{
                rule = "unnecessary-distinct"
                severity = "low"
                detail = "SELECT DISTINCT on single table without aggregation or JOIN - may be masking duplicate data or unnecessary"
            }
        }
    }

    # 11. ORDER BY on non-indexed expression (heuristic: ORDER BY function(column))
    if ($Sql -match '(?i)\bORDER\s+BY\s+\w+\s*\(') {
        $findings += @{
            rule = "order-by-expression"
            severity = "low"
            detail = "ORDER BY uses function/expression - may prevent index usage for sorting"
        }
    }

    # 12. IN without subquery on large list (heuristic: IN with many items)
    $inMatches = [regex]::Matches($Sql, '(?i)\bIN\s*\(([^)]+)\)')
    foreach ($m in $inMatches) {
        $items = $m.Groups[1].Value -split ',' | ForEach-Object { $_.Trim() }
        if ($items.Count -gt 100) {
            $findings += @{
                rule = "large-in-list"
                severity = "low"
                detail = "IN clause with $($items.Count) values - may cause query plan issues; consider temporary table or batch processing"
            }
        }
    }

    # 13. OR in WHERE (can prevent index merge)
    if ($Sql -match '(?i)\bWHERE\b') {
        $orCount = [regex]::Matches($Sql, '(?i)\bOR\b').Count
        if ($orCount -gt 2) {
            $findings += @{
                rule = "excessive-or"
                severity = "low"
                detail = "WHERE clause contains $orCount OR conditions - consider UNION or IN for better index usage"
            }
        }
    }

    # 14. NOT IN (usually slower than NOT EXISTS)
    if ($Sql -match '(?i)\bNOT\s+IN\b') {
        $findings += @{
            rule = "not-in"
            severity = "low"
            detail = "NOT IN can be slow with NULL values; prefer NOT EXISTS"
        }
    }

    # 15. LIKE without wildcard (equals instead)
    if ($Sql -match "(?i)\bLIKE\s+''[^%_]+''") {
        $findings += @{
            rule = "like-without-wildcard"
            severity = "low"
            detail = "LIKE used without wildcards; use = instead for exact match"
        }
    }

    return $findings
}

$files = Get-SourceFiles -Dir $ProjectDir
$queries = @()
$seenQueries = @{}  # dedup: "file:line:sql-hash"

foreach ($file in $files) {
    $relativePath = $file.FullName.Substring($ProjectDir.Length).TrimStart('\')
    try {
        $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
    } catch { continue }

    $literals = Find-StringLiterals -Content $content
    foreach ($lit in $literals) {
        $sql = $lit.sql.Trim()
        if (-not $sql) { continue }

        $dedupKey = "${relativePath}:${($lit.line)}:$( $sql.GetHashCode() )"
        if ($seenQueries.ContainsKey($dedupKey)) { continue }
        $seenQueries[$dedupKey] = $true

        $findings = @(Get-AntiPatterns -Sql $sql)
        $dialect = "generic"

        # Detect dialect hints
        if ($sql -match '(?i)\bTOP\b') { $dialect = "mssql" }
        if ($sql -match '(?i)\bLIMIT\b') { $dialect = "mysql" }
        if ($sql -match '(?i)\bRETURNING\b') { $dialect = "postgres" }
        if ($sql -match '(?i)\bSYSDATE\b') { $dialect = "oracle" }

        # Attempt parseability heuristic
        $parseable = $false
        $upperSql = $sql.ToUpper()
        if ($upperSql -match '^\s*(SELECT|INSERT|UPDATE|DELETE|MERGE)\s') {
            $parseable = $true
            # Simple balance check: count quotes
            $singleQuotes = [regex]::Matches($sql, "'").Count
            $doubleQuotes = [regex]::Matches($sql, '"').Count
            if ($singleQuotes % 2 -ne 0 -or $doubleQuotes % 2 -ne 0) {
                $parseable = $false
            }
        }

        $queries += @{
            file = $relativePath
            line = $lit.line
            sql = $sql
            dialect = $dialect
            parseable = $parseable
            findings = $findings
        }
    }
}

$queryCount = $queries.Count
$findingsCount = 0
$severityCounts = @{ critical = 0; high = 0; medium = 0; low = 0 }
$ruleCounts = @{}
foreach ($q in $queries) {
    foreach ($f in $q.findings) {
        $findingsCount++
        $sev = $f.severity
        if ($severityCounts.ContainsKey($sev)) { $severityCounts[$sev]++ }
        $rule = $f.rule
        if (-not $ruleCounts.ContainsKey($rule)) { $ruleCounts[$rule] = 0 }
        $ruleCounts[$rule]++
    }
}

$output = @{
    queries = $queries
    counts = @{
        totalQueries = $queryCount
        totalFindings = $findingsCount
        bySeverity = $severityCounts
        byRule = $ruleCounts
    }
    summary = "Found $queryCount inline SQL query(s) with $findingsCount finding(s): $($severityCounts.critical) critical, $($severityCounts.high) high, $($severityCounts.medium) medium, $($severityCounts.low) low."
}

$json = $output | ConvertTo-Json -Depth 6
Write-Output $json

Write-Output "=== SQL Smell Harvest Complete ==="
Write-Output "  Scanned: $($files.Count) files in $ProjectDir"
Write-Output "  Queries found: $queryCount"
Write-Output "  Findings: $findingsCount (critical: $($severityCounts.critical), high: $($severityCounts.high), medium: $($severityCounts.medium), low: $($severityCounts.low))"
Write-Output "  By rule:"
foreach ($r in $ruleCounts.GetEnumerator() | Sort-Object Name) {
    Write-Output "    $($r.Key): $($r.Value)"
}
Write-Output ""
Write-Output "  Next step: run LLM analysis via SKILL.md steps 4-6"
