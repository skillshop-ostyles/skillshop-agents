[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.sql,*.ts,*.js,*.py,*.rb,*.java,*.go,*.php"
)

$ErrorActionPreference = 'Stop'
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

$declaredFKs = @()
$inferredCandidates = @()
$scannedFiles = 0

$extList = $Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

$tables = @{}

function Parse-DDL($content, $rel) {
    $lines = $content -split "`r`n|`n"
    $currentTable = ''

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()

        if ($line -match 'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?["`]?(\w+)["`]?') {
            $currentTable = $matches[1]
            if (-not $tables.ContainsKey($currentTable)) {
                $tables[$currentTable] = @{
                    columns = @{}
                    file = $rel
                }
            }
            continue
        }

        if ($currentTable -and $line -match '^\s*(\w+)\s+(\w+)') {
            $colName = $matches[1]
            $colType = $matches[2]
            if ($colName -in @('PRIMARY', 'FOREIGN', 'UNIQUE', 'CHECK', 'CONSTRAINT', 'KEY', 'INDEX', 'CREATE', 'ALTER', 'DROP')) {
                if ($line -match 'FOREIGN\s+KEY\s*\(\s*(\w+)\s*\)\s*REFERENCES\s+(\w+)') {
                    $fkCol = $matches[1]
                    $refTable = $matches[2]
                    $script:declaredFKs += @{
                        fromTable = $currentTable
                        fromCol = $fkCol
                        toTable = $refTable
                        toCol = 'id'
                        file = $rel
                        line = ($i + 1)
                    }
                }
                continue
            }
            $tables[$currentTable].columns[$colName] = @{
                type = $colType
                file = $rel
            }
        }
    }
}

function Infer-From-Naming($tables) {
    $candidates = @()
    foreach ($tableName in $tables.Keys) {
        $table = $tables[$tableName]
        foreach ($colName in $table.columns.Keys) {
            if ($colName -match '^(.*?)_id$') {
                $prefix = $matches[1]
                $possibleTargets = @()
                foreach ($t in $tables.Keys) {
                    if ($t -eq $tableName) { continue }
                    if ($t -match "^${prefix}s?$") {
                        $possibleTargets += $t
                    }
                }
                foreach ($target in $possibleTargets) {
                    $candidates += @{
                        fromTable = $tableName
                        fromCol = $colName
                        toTable = $target
                        toCol = 'id'
                        evidence = 'naming'
                        confidence = 0.5
                        file = $table.columns[$colName].file
                    }
                }
            }
        }
    }
    return $candidates
}

function Infer-From-Joins($content, $rel) {
    $candidates = @()
    $lines = $content -split "`r`n|`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match 'JOIN\s+(\w+)\s+(\w+)\s+ON\s+(\w+)\.(\w+)\s*=\s*(\w+)\.(\w+)') {
            $rightTable = $matches[1]
            $rightAlias = $matches[2]
            $leftAlias = $matches[3]
            $leftCol = $matches[4]
            $rightAlias2 = $matches[5]
            $rightCol = $matches[6]

            $candidates += @{
                fromTable = $leftAlias
                fromCol = $leftCol
                toTable = $rightTable
                toCol = $rightCol
                evidence = 'join'
                confidence = 0.6
                file = $rel
                line = ($i + 1)
            }
        }
    }
    return $candidates
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

        if ($ext -eq '*.sql') {
            Parse-DDL $content $rel
        }

        $joinCandidates = Infer-From-Joins $content $rel
        foreach ($jc in $joinCandidates) {
            $existing = $inferredCandidates | Where-Object {
                $_.fromTable -eq $jc.fromTable -and $_.fromCol -eq $jc.fromCol -and
                $_.toTable -eq $jc.toTable -and $_.toCol -eq $jc.toCol
            }
            if ($existing) {
                $existing.evidence = "$($existing.evidence),join"
                $existing.confidence = [Math]::Min(0.95, $existing.confidence + 0.2)
            } else {
                $inferredCandidates += $jc
            }
        }
    }
}

$namingCandidates = Infer-From-Naming $tables
foreach ($nc in $namingCandidates) {
    $existing = $inferredCandidates | Where-Object {
        $_.fromTable -eq $nc.fromTable -and $_.fromCol -eq $nc.fromCol -and
        $_.toTable -eq $nc.toTable -and $_.toCol -eq $nc.toCol
    }
    if ($existing) {
        if ($existing.evidence -notmatch 'naming') {
            $existing.evidence = "$($existing.evidence),naming"
            $existing.confidence = [Math]::Min(0.95, $existing.confidence + 0.2)
        }
    } else {
        $isDeclared = $declaredFKs | Where-Object {
            $_.fromTable -eq $nc.fromTable -and $_.fromCol -eq $nc.fromCol -and
            $_.toTable -eq $nc.toTable
        }
        if (-not $isDeclared) {
            $inferredCandidates += $nc
        }
    }
}

$inferredCandidates = $inferredCandidates | Sort-Object confidence -Descending

$result = @{
    declaredFKs = $declaredFKs
    inferredCandidates = $inferredCandidates
    counts = @{
        scannedFiles = $scannedFiles
        declaredFKs = $declaredFKs.Count
        inferredCandidates = $inferredCandidates.Count
        byEvidence = @($inferredCandidates | Group-Object { $_.evidence } | ForEach-Object { @{ evidence = $_.Name; count = $_.Count } })
    }
}

Write-Output "=== Relationship Inference Complete ==="
Write-Output "  Files scanned: $scannedFiles"
Write-Output "  Declared FKs: $($declaredFKs.Count)"
Write-Output "  Inferred candidates: $($inferredCandidates.Count)"
foreach ($b in $result.counts.byEvidence) {
    Write-Output "  $($b.evidence): $($b.count)"
}

Write-Output ($result | ConvertTo-Json -Depth 5)
exit 0
