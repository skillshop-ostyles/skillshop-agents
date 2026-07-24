[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.sql,*.prisma"
)

$ErrorActionPreference = 'Stop'
$resolved = Resolve-Path -LiteralPath $ProjectDir -ErrorAction SilentlyContinue
if (-not $resolved) {
    Write-Error "Path not found: $ProjectDir"
    exit 1
}
$ProjectDir = $resolved.Path

$entities = @()
$scannedFiles = 0

$enumPattern = 'status|type|category|kind|level|priority|mode|state|phase|stage'
$nullablePattern = 'credit|limit|amount|total|note|description|comment|metadata|reason|detail'
$statusPattern = 'status|state|phase|stage|type|category|kind|level|mode'

function Parse-DDL($content, $rel) {
    $lines = $content -split "`r`n|`n"
    $currentTable = ''
    $currentEntity = $null

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].Trim()

        if ($line -match 'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?["`]?(\w+)["`]?') {
            if ($currentEntity) {
                $script:entities += $currentEntity
            }
            $currentTable = $matches[1]
            $currentEntity = @{
                table = $currentTable
                columns = @()
                fkDependencies = @()
                statusFields = @()
                nullableFields = @()
                uniqueFields = @()
                enumValues = @{}
                file = $rel
            }
            continue
        }

        if ($currentTable -and $line -match '^\s*(\w+)\s+(\w+)') {
            $colName = $matches[1]
            $colType = $matches[2]

            if ($colName -in @('PRIMARY', 'FOREIGN', 'UNIQUE', 'CHECK', 'CONSTRAINT', 'KEY', 'INDEX', 'CREATE', 'ALTER', 'DROP')) {
                if ($line -match 'FOREIGN\s+KEY\s*\(\s*(\w+)\s*\)\s*REFERENCES\s+(\w+)') {
                    $currentEntity.fkDependencies += @{ column = $matches[1]; refTable = $matches[2] }
                }
                if ($line -match 'UNIQUE\s*\(\s*(\w+)\s*\)') {
                    $currentEntity.uniqueFields += $matches[1]
                }
                continue
            }

            $nullable = -not ($line -match 'NOT\s+NULL')
            $default = ''
            if ($line -match 'DEFAULT\s+(\S+)') { $default = $matches[1] }

            $colNameLower = $colName.ToLower()

            if ($colNameLower -match $statusPattern) {
                $currentEntity.statusFields += $colName
                if ($default -and $default -ne 'CURRENT_TIMESTAMP') {
                    $currentEntity.enumValues[$colName] = @($default)
                }
            }

            if ($nullable -and $colNameLower -match $nullablePattern) {
                $currentEntity.nullableFields += $colName
            }

            if ($line -match 'UNIQUE' -or $line -match 'PRIMARY\s+KEY') {
                $currentEntity.uniqueFields += $colName
            }

            $currentEntity.columns += @{
                name = $colName
                type = $colType
                nullable = $nullable
                default = $default
            }
        }
    }

    if ($currentEntity) {
        $script:entities += $currentEntity
    }
}

$extList = $Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

foreach ($ext in $extList) {
    Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch 'node_modules|\.git|venv|bin|obj|__pycache__|dist|build'
    } | ForEach-Object {
        $fp = $_.FullName
        $scannedFiles++
        $content = Get-Content -LiteralPath $fp -Raw -ErrorAction SilentlyContinue
        if (-not $content) { return }
        $rel = $fp.Substring($ProjectDir.Length).TrimStart('\')
        Parse-DDL $content $rel
    }
}

$totalColumns = ($entities | ForEach-Object { $_.columns.Count } | Measure-Object -Sum).Sum

$result = @{
    entities = $entities
    counts = @{
        scannedFiles = $scannedFiles
        totalEntities = $entities.Count
        totalColumns = $totalColumns
    }
}

Write-Output "=== Seed Data Strategy Complete ==="
Write-Output "  Files scanned: $scannedFiles"
Write-Output "  Entities found: $($entities.Count)"
Write-Output "  Total columns: $totalColumns"

Write-Output ($result | ConvertTo-Json -Depth 5)
exit 0
