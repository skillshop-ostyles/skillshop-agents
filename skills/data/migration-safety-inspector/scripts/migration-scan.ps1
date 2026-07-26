[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$MigrationPattern = "*.sql"
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

# PROTECTION: never modify ~/.claude/.
function Normalize($p) {
    $base = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
    $expanded = if ($p.StartsWith('~')) { Join-Path $base $p.Substring(1) } else { $p }
    return [System.IO.Path]::GetFullPath($expanded).TrimEnd('\')
}
$claudeRoot = Normalize (Join-Path $env:USERPROFILE '.claude')
$targetPath = Normalize $ProjectDir
if ($targetPath -eq $claudeRoot -or $targetPath.StartsWith("$claudeRoot\")) {
    Write-Error "PROTECTION: ProjectDir is inside $claudeRoot. Aborting."
    exit 1
}

function Get-MigrationFiles {
    param([string]$Dir, [string]$Pattern)
    $all = Get-ChildItem -LiteralPath $Dir -Recurse -Filter $Pattern -File -ErrorAction SilentlyContinue
    $namingRegex = '(?i)^(\d{8}[_\.].*\.sql|V\d+__.*\.sql|.*_migration\..*)$'
    $result = @()
    foreach ($f in $all) {
        $name = $f.Name
        if ($name -match $namingRegex) {
            $result += $f
        }
    }
    return $result
}

function Get-ParentStatement([string]$line) {
    $line = $line.Trim()
    if ($line -eq '') { return $null }

    if ($line -notmatch ';') { return $null }

    if ($line -match '(?i)^\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)\b') {
        return $null
    }

    return $line
}

# Check if a line is a transaction control statement
function Is-TransactionControl([string]$line) {
    $t = $line.Trim()
    if ($t -match '(?i)^\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)\b') {
        return $true
    }
    return $false
}

function Test-TableRewriteStatement([string]$stmt) {
    $findings = @()

    if ($stmt -match '(?i)ALTER\s+TABLE\s+\S+\s+ALTER\s+COLUMN\s+\S+\s+TYPE\b') {
        $m = [regex]::Match($stmt, '(?i)ALTER\s+TABLE\s+(\S+)\s+ALTER\s+COLUMN\s+(\S+)\s+TYPE\b')
        $table = if ($m.Success) { $m.Groups[1].Value.Trim('[', ']', '"', '`') } else { '?' }
        $column = if ($m.Success) { $m.Groups[2].Value.Trim('[', ']', '"', '`') } else { '?' }
        $findings += @{
            rule = 'table-rewrite'
            severity = 'critical'
            description = "ALTER COLUMN TYPE on '$table.$column' causes full table rewrite and exclusive lock"
            ddl = $stmt.Trim()
        }
    }

    if ($stmt -match '(?i)ALTER\s+TABLE\s+\S+\s+ADD\s+COLUMN\s+\S+\s+[^(]+NOT\s+NULL\b') {
        # This has ADD COLUMN ... NOT NULL but check if it has a DEFAULT
        if ($stmt -notmatch '(?i)DEFAULT\s') {
            $m = [regex]::Match($stmt, '(?i)ALTER\s+TABLE\s+(\S+)\s+ADD\s+COLUMN\s+(\S+)')
            $table = if ($m.Success) { $m.Groups[1].Value.Trim('[', ']', '"', '`') } else { '?' }
            $column = if ($m.Success) { $m.Groups[2].Value.Trim('[', ']', '"', '`') } else { '?' }
            $findings += @{
                rule = 'table-rewrite'
                severity = 'high'
                description = "ADD COLUMN NOT NULL on '$table.$column' without DEFAULT causes table rewrite - use NOT NULL with DEFAULT or multi-step approach"
                ddl = $stmt.Trim()
            }
        }
    }

    return $findings
}

function Test-MissingConcurrently([string]$stmt) {
    $findings = @()

    if ($stmt -match '(?i)^\s*CREATE\s+(UNIQUE\s+)?INDEX\b') {
        if ($stmt -notmatch '(?i)CONCURRENTLY') {
            $m = [regex]::Match($stmt, '(?i)CREATE\s+(UNIQUE\s+)?INDEX\s+(\S+)\s+ON\s+(\S+)')
            $index = if ($m.Success) { $m.Groups[2].Value.Trim('[', ']', '"', '`') } else { '?' }
            $table = if ($m.Success) { $m.Groups[3].Value.Trim('[', ']', '"', '`') } else { '?' }
            $findings += @{
                rule = 'missing-concurrently'
                severity = 'high'
                description = "CREATE INDEX '$index' on '$table' without CONCURRENTLY blocks writes on the table"
                ddl = $stmt.Trim()
            }
        }
    }

    if ($stmt -match '(?i)^\s*REINDEX\b' -and $stmt -notmatch '(?i)CONCURRENTLY') {
        $findings += @{
            rule = 'missing-concurrently'
            severity = 'high'
            description = "REINDEX without CONCURRENTLY blocks writes during rebuild"
            ddl = $stmt.Trim()
        }
    }

    if ($stmt -match '(?i)^\s*VACUUM\b' -and $stmt -notmatch '(?i)FULL\b') {
        # VACUUM without FULL doesn't need CONCURRENTLY, but VACUUM FULL does
    }
    if ($stmt -match '(?i)^\s*VACUUM\s+FULL\b' -and $stmt -notmatch '(?i)CONCURRENTLY') {
        $findings += @{
            rule = 'missing-concurrently'
            severity = 'high'
            description = "VACUUM FULL without CONCURRENTLY blocks writes during rebuild"
            ddl = $stmt.Trim()
        }
    }

    return $findings
}

function Test-Destructive([string]$stmt) {
    $findings = @()

    if ($stmt -match '(?i)^\s*DROP\s+TABLE\b') {
        $hasIfExists = $stmt -match '(?i)IF\s+EXISTS'
        $m = [regex]::Match($stmt, '(?i)DROP\s+TABLE\s+(?:IF\s+EXISTS\s+)?(\S+)')
        $table = if ($m.Success) { $m.Groups[1].Value.Trim('[', ']', '"', '`') } else { '?' }
        $findings += @{
            rule = 'destructive'
            severity = 'critical'
            description = "DROP TABLE '$table'$(if (-not $hasIfExists) { ' without IF EXISTS' }) - data loss, verify backup and rollback plan"
            ddl = $stmt.Trim()
        }
    }

    if ($stmt -match '(?i)^\s*ALTER\s+TABLE\s+\S+\s+DROP\s+COLUMN\b') {
        $hasIfExists = $stmt -match '(?i)IF\s+EXISTS'
        $m = [regex]::Match($stmt, '(?i)ALTER\s+TABLE\s+(\S+)\s+DROP\s+COLUMN\s+(?:IF\s+EXISTS\s+)?(\S+)')
        $table = if ($m.Success) { $m.Groups[1].Value.Trim('[', ']', '"', '`') } else { '?' }
        $column = if ($m.Success) { $m.Groups[2].Value.Trim('[', ']', '"', '`') } else { '?' }
        $findings += @{
            rule = 'destructive'
            severity = 'critical'
            description = "DROP COLUMN '$column' on '$table'$(if (-not $hasIfExists) { ' without IF EXISTS' }) - data loss, verify backup and rollback plan"
            ddl = $stmt.Trim()
        }
    }

    if ($stmt -match '(?i)^\s*TRUNCATE\b') {
        $m = [regex]::Match($stmt, '(?i)TRUNCATE\s+(\S+)')
        $table = if ($m.Success) { $m.Groups[1].Value.Trim('[', ']', '"', '`') } else { '?' }
        $findings += @{
            rule = 'destructive'
            severity = 'critical'
            description = "TRUNCATE '$table' - irreversible data loss, verify backup before running"
            ddl = $stmt.Trim()
        }
    }

    return $findings
}

function Test-UnsafeConstraint([string]$stmt) {
    $findings = @()

    if ($stmt -match '(?i)ADD\s+(CONSTRAINT\s+\S+\s+)?FOREIGN\s+KEY\b') {
        if ($stmt -notmatch '(?i)NOT\s+VALID') {
            $m = [regex]::Match($stmt, '(?i)ALTER\s+TABLE\s+(\S+)')
            $table = if ($m.Success) { $m.Groups[1].Value.Trim('[', ']', '"', '`') } else { '?' }
            $findings += @{
                rule = 'unsafe-constraint'
                severity = 'high'
                description = "ADD FOREIGN KEY on '$table' without NOT VALID - validates all existing rows, holds lock, may fail on existing data"
                ddl = $stmt.Trim()
            }
        }
    }

    return $findings
}

function Test-MissingIfExists([string]$stmt) {
    $findings = @()

    $dropPatterns = @(
        '(?i)^\s*DROP\s+(TABLE|INDEX|VIEW|SEQUENCE|FUNCTION|PROCEDURE|TRIGGER|CONSTRAINT)\b',
        '(?i)ALTER\s+TABLE\s+\S+\s+DROP\s+COLUMN\b',
        '(?i)ALTER\s+TABLE\s+\S+\s+DROP\s+CONSTRAINT\b'
    )
    foreach ($pat in $dropPatterns) {
        if ($stmt -match $pat) {
            $type = $matches[1]
            if ($stmt -notmatch '(?i)IF\s+EXISTS') {
                $findings += @{
                    rule = 'missing-if-exists'
                    severity = 'low'
                    description = "DROP $type without IF EXISTS - fails if object does not exist"
                    ddl = $stmt.Trim()
                }
            }
        }
    }

    if ($stmt -match '(?i)^\s*CREATE\s+(TABLE|INDEX|VIEW|SEQUENCE)\b' -and $stmt -notmatch '(?i)IF\s+NOT\s+EXISTS') {
        if ($stmt -notmatch '(?i)CREATE\s+INDEX.*CONCURRENTLY') {
            $type = $matches[1]
            $findings += @{
                rule = 'missing-if-exists'
                severity = 'low'
                description = "CREATE $type without IF NOT EXISTS - fails if object already exists"
                ddl = $stmt.Trim()
            }
        }
    }

    return $findings
}

function Test-DmlOnMigration([string]$stmt) {
    $findings = @()

    if ($stmt -match '(?i)^\s*(INSERT\s+INTO|UPDATE\s+|DELETE\s+FROM)\b') {
        $action = 'DML'
        if ($stmt -match '(?i)^\s*INSERT\s+INTO\b') { $action = 'INSERT' }
        elseif ($stmt -match '(?i)^\s*UPDATE\b') { $action = 'UPDATE' }
        elseif ($stmt -match '(?i)^\s*DELETE\s+FROM\b') { $action = 'DELETE' }

        $tableMatch = [regex]::Match($stmt, "(?i)(?:INSERT\s+INTO|UPDATE|DELETE\s+FROM)\s+(\S+)")
        $table = if ($tableMatch.Success) { $tableMatch.Groups[1].Value.Trim('[', ']', '"', '`') } else { '?' }

        $findings += @{
            rule = 'dml-on-migration'
            severity = 'medium'
            description = "$action on '$table' in migration file - DML on existing tables should be explicit and reversible"
            ddl = $stmt.Trim()
        }
    }

    return $findings
}

function Test-TransactionWrapper([string[]]$lines, [string]$file) {
    $findings = @()
    $ddlStatements = @()
    $inTransaction = $false
    $hasDdl = $false

    foreach ($line in $lines) {
        $t = $line.Trim()
        if ($t -eq '' -or $t.StartsWith('--') -or $t.StartsWith('/*') -or $t.StartsWith('#')) { continue }
        if ($t -match '(?i)^\s*BEGIN\b') { $inTransaction = $true }
        if ($t -match '(?i)^\s*(COMMIT|ROLLBACK)\b') { $inTransaction = $false }

        if ($t -match '(?i)^\s*(ALTER\s+TABLE|CREATE\s+TABLE|CREATE\s+INDEX|DROP\s+|TRUNCATE|REINDEX|VACUUM)\b') {
            $hasDdl = $true
            if ($t -notmatch ';') {
                $ddlStatements += $t
            }
        } elseif ($ddlStatements.Count -gt 0) {
            $ddlStatements[-1] += " $t"
            if ($t.EndsWith(';')) {
                $combined = $ddlStatements[-1]
                $ddlStatements = @()
                if (-not $inTransaction -and $combined -notmatch '(?i)^\s*CREATE\s+INDEX.*CONCURRENTLY') {
                    $findings += @{
                        rule = 'missing-transaction'
                        severity = 'low'
                        description = "DDL statement not wrapped in an explicit transaction - partial failure may leave schema inconsistent"
                        ddl = $combined.Trim()
                    }
                }
            }
        }
    }

    if ($hasDdl -and -not $inTransaction -and $findings.Count -eq 0) {
        # Check if any DDL ended without being inside a transaction (for single-line statements)
    }

    return $findings
}

# Parse each file: split into statements by semicolons, preserve line numbers
function Parse-Statements([string[]]$lines) {
    $statements = @()
    $currentStmt = ''
    $startLine = 0
    $inBlockComment = $false

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $trimmed = $line.Trim()

        # Skip empty lines
        if ($trimmed -eq '' -and $currentStmt -eq '') { continue }

        # Handle block comments
        if ($inBlockComment) {
            if ($trimmed -match '\*/') {
                $inBlockComment = $false
                $line = $line.Substring($line.IndexOf('*/') + 2)
                $trimmed = $line.Trim()
                if ($trimmed -eq '') { continue }
            } else {
                continue
            }
        }
        if ($trimmed -match '(?s)/\*') {
            $startIdx = $line.IndexOf('/*')
            $endIdx = $line.IndexOf('*/', $startIdx + 2)
            if ($endIdx -ge 0) {
                $before = $line.Substring(0, $startIdx)
                $after = $line.Substring($endIdx + 2)
                $line = $before + $after
                $trimmed = $line.Trim()
                if ($trimmed -eq '' -and $currentStmt -eq '') { continue }
            } else {
                $inBlockComment = $true
                $line = $line.Substring(0, $startIdx)
                $trimmed = $line.Trim()
                if ($trimmed -eq '' -and $currentStmt -eq '') { continue }
            }
        }

        # Handle single-line comments
        $commentIdx = -1
        $inString = $false
        for ($j = 0; $j -lt $line.Length; $j++) {
            if ($line[$j] -eq "'") { $inString = -not $inString }
            if (-not $inString -and $j -lt $line.Length - 1 -and $line[$j] -eq '-' -and $line[$j+1] -eq '-') {
                $commentIdx = $j
                break
            }
        }
        if ($commentIdx -ge 0 -and -not $inString) {
            $line = $line.Substring(0, $commentIdx)
            $trimmed = $line.Trim()
            if ($trimmed -eq '' -and $currentStmt -eq '') { continue }
        }

        # Remove inline SQL comments after the statement
        $hashIdx = -1
        $inString2 = $false
        for ($j = 0; $j -lt $line.Length; $j++) {
            if ($line[$j] -eq "'") { $inString2 = -not $inString2 }
            if (-not $inString2 -and $line[$j] -eq '#') {
                $hashIdx = $j
                break
            }
        }
        if ($hashIdx -ge 0 -and -not $inString2) {
            $line = $line.Substring(0, $hashIdx)
            $trimmed = $line.Trim()
        }

        if ($currentStmt -eq '') { $startLine = $i + 1 }

        # Check if line ends with a semicolon
        $trimmed2 = $line.Trim()
        if ($trimmed2 -ne '') {
            if ($currentStmt -eq '') {
                $currentStmt = $trimmed2
            } else {
                $currentStmt += " $trimmed2"
            }
        }

        if ($trimmed2.EndsWith(';')) {
            $stmt = $currentStmt.TrimEnd(';').Trim()
            if ($stmt -ne '') {
                $statements += @{ line = $startLine; text = "$stmt;" }
            }
            $currentStmt = ''
        }
    }

    # Handle last statement without trailing semicolon
    if ($currentStmt -ne '') {
        $stmt = $currentStmt.Trim()
        if ($stmt -ne '') {
            $statements += @{ line = $startLine; text = "$stmt;" }
        }
    }

    Write-Output -NoEnumerate $statements
}

# Main collection
$totalFiles = 0
$totalStatements = 0
$allMigrations = @()

$migrationFiles = Get-MigrationFiles -Dir $ProjectDir -Pattern $MigrationPattern

foreach ($file in $migrationFiles) {
    $totalFiles++
    $relPath = $file.FullName.Substring($ProjectDir.Length).TrimStart('\')
    $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    $lines = $content -split "`r`n|`n"

    $statements = Parse-Statements -lines $lines
    $totalStatements += $statements.Count

    $findings = @()
    $seenTransactionBlock = $false
    $inTransaction = $false

    foreach ($line in $lines) {
        $t = $line.Trim()
        if ($t -match '(?i)^\s*BEGIN\b') { $inTransaction = $true; $seenTransactionBlock = $true }
        if ($t -match '(?i)^\s*(COMMIT|ROLLBACK)\b') { $inTransaction = $false }
    }

    $hasDdl = $false
    foreach ($stmt in $statements) {
        $s = $stmt.text

        if ($s -match '(?i)^\s*(ALTER\s+TABLE|CREATE\s+TABLE|CREATE\s+INDEX|DROP\s+|TRUNCATE|REINDEX|VACUUM)\b') {
            $hasDdl = $true
        }

        $findings += Test-TableRewriteStatement -stmt $s
        $findings += Test-MissingConcurrently -stmt $s
        $findings += Test-Destructive -stmt $s
        $findings += Test-UnsafeConstraint -stmt $s
        $findings += Test-MissingIfExists -stmt $s
        $findings += Test-DmlOnMigration -stmt $s

        foreach ($f in $findings) {
            if ($f.ddl -eq $s.Trim()) {
                $f.line = $stmt.line
                $f.file = $relPath
            }
        }
    }

    if ($hasDdl -and -not $seenTransactionBlock -and $relPath -notmatch '(?i)rollback|revert') {
        $findings += @{
            rule = 'missing-transaction'
            severity = 'low'
            line = 1
            file = $relPath
            description = "Migration file contains DDL but no explicit BEGIN/COMMIT transaction wrapper - partial failure risk"
            ddl = "(entire file)"
        }
    }

    $stmtObjects = @($statements | ForEach-Object {
        @{ line = $_.line; text = $_.text }
    })

    $allMigrations += @{
        file = $relPath
        statements = $stmtObjects
        findings = $findings
    }
}

$findingCount = @($allMigrations | ForEach-Object { $_.findings }).Count
$criticalCount = @($allMigrations | ForEach-Object { $_.findings } | Where-Object { $_.severity -eq 'critical' }).Count
$highCount = @($allMigrations | ForEach-Object { $_.findings } | Where-Object { $_.severity -eq 'high' }).Count
$mediumCount = @($allMigrations | ForEach-Object { $_.findings } | Where-Object { $_.severity -eq 'medium' }).Count
$lowCount = @($allMigrations | ForEach-Object { $_.findings } | Where-Object { $_.severity -eq 'low' }).Count

$result = @{
    scannedDir = $ProjectDir
    pattern = $MigrationPattern
    migrations = $allMigrations
    summary = @{
        filesScanned = $totalFiles
        statementsFound = $totalStatements
        totalFindings = $findingCount
        bySeverity = @{
            critical = $criticalCount
            high = $highCount
            medium = $mediumCount
            low = $lowCount
        }
    }
}

Write-Output "=== Migration Safety Scan Complete ==="
Write-Output "  Directory: $ProjectDir"
Write-Output "  Migration files: $totalFiles"
Write-Output "  Statements found: $totalStatements"
Write-Output "  Total findings: $findingCount"
Write-Output "    Critical: $criticalCount"
Write-Output "    High: $highCount"
Write-Output "    Medium: $mediumCount"
Write-Output "    Low: $lowCount"

Write-Output ($result | ConvertTo-Json -Depth 8)
exit 0
