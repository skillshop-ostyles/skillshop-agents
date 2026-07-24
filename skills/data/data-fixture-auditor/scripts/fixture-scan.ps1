<#
.SYNOPSIS
    Scan fixture files and audit test data coverage.
.DESCRIPTION
    Finds fixture files (JSON, YAML, SQL INSERT) by naming convention, parses
    entities and field values, computes coverage metrics (cardinality, constant
    fields, null ratio), and compares against companion schema (DDL or JSON
    Schema) if available.
.PARAMETER ProjectDir
    Project directory to scan.
.PARAMETER Extensions
    Comma-separated file extensions to include. Default: *.json,*.yaml,*.yml,*.sql
.EXAMPLE
    .\fixture-scan.ps1 -ProjectDir tests/fixtures/smoke/src
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ProjectDir,

    [Parameter(Position = 1)]
    [string]$Extensions = "*.json,*.yaml,*.yml,*.sql"
)

$ErrorActionPreference = 'Stop'

# ── Resolve paths ──────────────────────────────────────────────────────────────
$resolvedDir = Resolve-Path -LiteralPath $ProjectDir -ErrorAction Stop

# ── Extension filters ──────────────────────────────────────────────────────────
$extensionFilters = $Extensions.Split(',', [StringSplitOptions]::RemoveEmptyEntries) | ForEach-Object {
    $_.Trim().TrimStart('*')
}

# ── Fixture naming patterns ────────────────────────────────────────────────────
function Test-FixtureFilePath {
    param([string]$Path, [string]$Name)
    $patterns = @('fixture', 'seed', 'test-data', 'test_data')
    $pathParts = $Path -replace '\\', '/' -split '/'
    foreach ($part in $pathParts) {
        foreach ($pat in $patterns) {
            if ($part -match [regex]::Escape($pat) -or $part -like "*$pat*") {
                return $true
            }
        }
    }
    foreach ($pat in $patterns) {
        if ($Name -match [regex]::Escape($pat) -or $Name -like "*$pat*") {
            return $true
        }
    }
    return $false
}

# ── Find fixture files ─────────────────────────────────────────────────────────
Write-Verbose "Scanning $resolvedDir for fixture files..."

$fixtureFiles = Get-ChildItem -LiteralPath $resolvedDir -Recurse -File | Where-Object {
    if ($_.Name -match '^schema\.') { return $false }
    $extOk = $false
    foreach ($f in $extensionFilters) {
        if ($_.Extension -match [regex]::Escape($f.TrimStart('*'))) {
            $extOk = $true
            break
        }
    }
    $extOk -and (Test-FixtureFilePath -Path $_.FullName -Name $_.Name)
}

if (-not $fixtureFiles) {
    Write-Warning "No fixture files found in $resolvedDir"
    $output = @{
        projectDir = $resolvedDir
        fixtures   = @()
        summary    = @{
            totalFixtureFiles = 0
            totalEntities     = 0
            totalRecords      = 0
            overallFieldCoverage = 'N/A'
        }
    }
    $output | ConvertTo-Json -Depth 10
    exit 0
}

# ── Load schema files (JSON Schema first, then SQL DDL) ────────────────────────
$schema = @{}    # from JSON schema files
$sqlSchema = @{} # from SQL DDL files

$schemaFiles = Get-ChildItem -LiteralPath $resolvedDir -Recurse -File | Where-Object {
    $_.Name -eq 'schema.json'
}
foreach ($sf in $schemaFiles) {
    try {
        $content = Get-Content -LiteralPath $sf.FullName -Raw -Encoding UTF8
        $parsed = $content | ConvertFrom-Json
        foreach ($key in $parsed.PSObject.Properties.Name) {
            $schema[$key] = @{}
            foreach ($field in $parsed.$key.PSObject.Properties.Name) {
                $schema[$key][$field] = $parsed.$key.$field
            }
        }
    } catch {
        Write-Warning "Failed to parse schema $($sf.FullName): $_"
    }
}

$sqlKeywords = @('PRIMARY', 'KEY', 'INDEX', 'CONSTRAINT', 'UNIQUE', 'CHECK',
    'FOREIGN', 'REFERENCES', 'CASCADE', 'ON', 'DELETE', 'UPDATE', 'SET',
    'NULL', 'NOT', 'DEFAULT', 'TABLE', 'CREATE', 'ALTER', 'DROP', 'INSERT',
    'INTO', 'VALUES', 'SELECT', 'FROM', 'WHERE', 'AND', 'OR', 'IN', 'IS',
    'EXISTS', 'IF', 'UNIQUE')

$sqlSchemaFiles = Get-ChildItem -LiteralPath $resolvedDir -Recurse -File | Where-Object {
    $_.Name -like '*schema*' -and $_.Extension -eq '.sql'
}
foreach ($sf in $sqlSchemaFiles) {
    try {
        $content = Get-Content -LiteralPath $sf.FullName -Raw -Encoding UTF8
        $tableRegex = [regex]::new(
            'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?[`"\[\]]?(\w+)[`"\[\]]?\s*\(([\s\S]*?)\)\s*;',
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        )
        $tableMatches = $tableRegex.Matches($content)
        foreach ($m in $tableMatches) {
            $tableName = $m.Groups[1].Value
            $columnsText = $m.Groups[2].Value
            $sqlSchema[$tableName] = @{}
            $lines = $columnsText -split '\r?\n'
            foreach ($line in $lines) {
                $cl = $line.Trim().TrimEnd(',').Trim()
                if (-not $cl) { continue }
                $parts = $cl -split '\s+', 3
                if ($parts.Count -ge 2) {
                    $colName = $parts[0].Trim('`"[]')
                    $colType = $parts[1]
                    if ($colName.ToUpper() -notin $sqlKeywords) {
                        $sqlSchema[$tableName][$colName] = $colType
                    }
                }
            }
        }
    } catch {
        Write-Warning "Failed to parse SQL schema $($sf.FullName): $_"
    }
}

# ── Helper: detect if value is null-like ───────────────────────────────────────
function Test-IsNull {
    param($Value)
    return ($null -eq $Value) -or ($Value -is [System.Management.Automation.Internal.AutomationNull])
}

# ── Parse fixture files ────────────────────────────────────────────────────────
$fixtures = @()

foreach ($file in $fixtureFiles) {
    $relativePath = $file.FullName.Substring($resolvedDir.Length).TrimStart('\')
    Write-Verbose "Processing: $relativePath"

    try {
        $raw = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
    } catch {
        Write-Warning "Could not read $($file.FullName): $_"
        continue
    }

    $entities = @{}

    # ── JSON parser ────────────────────────────────────────────────────────────
    if ($file.Extension -eq '.json') {
        try {
            $data = $raw | ConvertFrom-Json
            foreach ($prop in $data.PSObject.Properties.Name) {
                $value = $data.$prop
                if ($null -ne $value -and $value -is [System.Array] -and $value.Count -gt 0) {
                    $first = $value[0]
                    if ($null -ne $first -and $first -is [System.Management.Automation.PSCustomObject]) {
                        $entities[$prop] = @($value)
                    }
                }
            }
        } catch {
            Write-Warning "Failed to parse JSON $($file.Name): $_"
        }
    }

    # ── YAML parser ────────────────────────────────────────────────────────────
    elseif ($file.Extension -in '.yaml', '.yml') {
        try {
            $yamlModule = Get-Module -ListAvailable -Name powershell-yaml
            if (-not $yamlModule) {
                Write-Warning "YAML parsing requires powershell-yaml module; skipping $($file.Name)"
                continue
            }
            Import-Module powershell-yaml -ErrorAction Stop
            $data = $raw | ConvertFrom-Yaml
            if ($data -is [System.Collections.Hashtable]) {
                foreach ($key in $data.Keys) {
                    $value = $data[$key]
                    if ($null -ne $value -and $value -is [System.Collections.IList] -and $value.Count -gt 0) {
                        $first = $value[0]
                        if ($null -ne $first -and $first -is [System.Collections.Hashtable]) {
                            $entities[$key] = $value
                        }
                    }
                }
            }
        } catch {
            Write-Warning "Failed to parse YAML $($file.Name): $_"
            continue
        }
    }

    # ── SQL INSERT parser ──────────────────────────────────────────────────────
    elseif ($file.Extension -eq '.sql') {
        $insertRegex = [regex]::new(
            'INSERT\s+INTO\s+[`"\[\]]?(\w+)[`"\[\]]?\s*' +
            '(?:\s*\(([^)]+)\))?\s*VALUES\s*' +
            '((?:\([^)]+\)\s*,?\s*)+)',
            [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
        )
        $matches = $insertRegex.Matches($raw)
        foreach ($m in $matches) {
            $tableName = $m.Groups[1].Value
            $columnsStr = $m.Groups[2].Value
            $valuesStr  = $m.Groups[3].Value

            if (-not $columnsStr) { continue }

            $columns = $columnsStr -split ',' | ForEach-Object {
                $_.Trim().Trim('`"[]')
            }

            $valueTuples = [regex]::Matches($valuesStr, '\(([^)]+)\)')
            $records = @()
            foreach ($vt in $valueTuples) {
                $vals = $vt.Groups[1].Value -split ',' | ForEach-Object {
                    $_.Trim().Trim("'")
                }
                if ($columns.Count -gt 0 -and $vals.Count -ge $columns.Count) {
                    $rec = [PSCustomObject]@{}
                    for ($i = 0; $i -lt $columns.Count; $i++) {
                        $rec | Add-Member -MemberType NoteProperty -Name $columns[$i] -Value $vals[$i]
                    }
                    $records += $rec
                }
            }
            if ($records.Count -gt 0) {
                if (-not $entities.ContainsKey($tableName)) {
                    $entities[$tableName] = @()
                }
                $entities[$tableName] += $records
            }
        }
    }

    # ── Skip if no entities found ──────────────────────────────────────────────
    if ($entities.Count -eq 0) {
        Write-Warning "No parseable entities in $($file.Name)"
        $fixtures += @{
            file          = $relativePath
            entity        = 'N/A'
            recordCount   = 0
            fieldCoverage = @{ populated = 0; total = 0; ratio = 0 }
        }
        continue
    }

    # ── Compute metrics per entity ─────────────────────────────────────────────
    foreach ($entityName in $entities.Keys) {
        $records = $entities[$entityName]
        if ($records.Count -eq 0) { continue }

        $fieldValues = @{}
        foreach ($rec in $records) {
            foreach ($prop in $rec.PSObject.Properties.Name) {
                if (-not $fieldValues.ContainsKey($prop)) {
                    $fieldValues[$prop] = @()
                }
                $fieldValues[$prop] += , $rec.$prop
            }
        }

        # Determine expected fields from schema (prefer JSON Schema over SQL)
        $expectedFields = @()
        if ($schema.ContainsKey($entityName)) {
            $expectedFields = $schema[$entityName].Keys | Sort-Object
        } elseif ($sqlSchema.ContainsKey($entityName)) {
            $expectedFields = $sqlSchema[$entityName].Keys | Sort-Object
        }

        # Fields present in the data
        $dataFields = $fieldValues.Keys | Sort-Object

        # Per-field metrics
        $populatedCount  = 0
        $cardinality     = @{}
        $constantFields  = @()
        $neverPopulated  = @()
        $valueDistrib    = @{}
        $nullCounts      = @{}

        foreach ($fn in $dataFields) {
            $vals = $fieldValues[$fn]
            $nonNull = @($vals | Where-Object { -not (Test-IsNull $_) })
            $nullCount = @($vals | Where-Object { Test-IsNull $_ }).Count
            $nullCounts[$fn] = $nullCount

            if ($nonNull.Count -gt 0) {
                $populatedCount++
                $distinct = @($nonNull | Sort-Object -Unique)
                $cardinality[$fn] = $distinct.Count
                $distrib = @{}
                foreach ($dv in $distinct) {
                    $cnt = @($nonNull | Where-Object { $_ -eq $dv }).Count
                    $key = if ($null -eq $dv) { '$null' } else { $dv.ToString() }
                    $distrib[$key] = $cnt
                }
                $valueDistrib[$fn] = $distrib
                if ($distinct.Count -eq 1) {
                    $constantFields += $fn
                }
            } else {
                $neverPopulated += $fn
            }
        }

        # Fields in schema but absent from data => never populated
        $schemaOnlyFields = $expectedFields | Where-Object { $dataFields -notcontains $_ }
        $neverPopulated = @($neverPopulated + $schemaOnlyFields | Sort-Object -Unique)

        # Fields in data that are always null => never populated (already in $neverPopulated)
        $totalFields = if ($expectedFields.Count -gt 0) {
            [Math]::Max($expectedFields.Count, [Math]::Max($dataFields.Count, 1))
        } else {
            [Math]::Max($dataFields.Count, 1)
        }

        $entry = @{
            file                 = $relativePath
            entity               = $entityName
            recordCount          = $records.Count
            fieldCoverage        = @{
                populated = $populatedCount
                total     = $totalFields
                ratio     = [Math]::Round($populatedCount / $totalFields, 4)
            }
            cardinality          = $cardinality
            constantFields       = $constantFields
            neverPopulatedFields = $neverPopulated
            valueDistributions   = $valueDistrib
            nullFieldCounts      = $nullCounts
        }

        # Schema comparison annotations
        if ($expectedFields.Count -gt 0) {
            $populatedSchema = $expectedFields | Where-Object { $dataFields -contains $_ }
            $missingSchema   = $expectedFields | Where-Object { $dataFields -notcontains $_ }
            $entry['schemaMatchedFields'] = @($populatedSchema)
            $entry['schemaMissingFields'] = @($missingSchema)
        }

        $fixtures += $entry
    }
}

# ── Build output ───────────────────────────────────────────────────────────────
$totalRecords = 0
$totalPop = 0
$totalTot = 0
foreach ($fx in $fixtures) {
    $totalRecords += $fx.recordCount
    $totalPop += $fx.fieldCoverage.populated
    $totalTot += $fx.fieldCoverage.total
}

$output = @{
    projectDir = $resolvedDir
    fixtures   = $fixtures
    summary    = @{
        totalFixtureFiles   = @($fixtures | ForEach-Object { $_.file } | Sort-Object -Unique).Count
        totalEntities       = $fixtures.Count
        totalRecords        = $totalRecords
        overallFieldCoverage = if ($totalTot -gt 0) {
            "$([Math]::Round($totalPop / $totalTot * 100, 1))%"
        } else { 'N/A' }
    }
}

# ── Console summary ────────────────────────────────────────────────────────────
Write-Host "`n=== Fixture Audit Summary ===" -ForegroundColor Cyan
Write-Host "Project : $resolvedDir"
Write-Host "Files   : $($output.summary.totalFixtureFiles)"
Write-Host "Entities: $($output.summary.totalEntities)"
Write-Host "Records : $($output.summary.totalRecords)"
Write-Host "Coverage: $($output.summary.overallFieldCoverage)"

foreach ($fx in $fixtures) {
    Write-Host "`n  [$($fx.entity)] $($fx.file)" -ForegroundColor Yellow
    Write-Host "    Records     : $($fx.recordCount)"
    Write-Host "    Coverage    : $($fx.fieldCoverage.populated)/$($fx.fieldCoverage.total) ($([Math]::Round($fx.fieldCoverage.ratio * 100, 1))%)"
    if ($fx.constantFields.Count -gt 0) {
        Write-Host "    Constants   : $($fx.constantFields -join ', ')" -ForegroundColor Magenta
    }
    if ($fx.neverPopulatedFields.Count -gt 0) {
        Write-Host "    Never pop.  : $($fx.neverPopulatedFields -join ', ')" -ForegroundColor DarkYellow
    }
    if ($fx.ContainsKey('schemaMissingFields') -and $fx.schemaMissingFields.Count -gt 0) {
        Write-Host "    Missing     : $($fx.schemaMissingFields -join ', ')" -ForegroundColor Red
    }
    foreach ($field in @($fx.cardinality.Keys)) {
        if ($fx.cardinality[$field] -eq 1) {
            Write-Host "    * $field has cardinality 1 (all same)" -ForegroundColor DarkGray
        }
    }
}

Write-Host "`n---" -ForegroundColor Cyan

# ── JSON output to pipeline ────────────────────────────────────────────────────
$output | ConvertTo-Json -Depth 10

exit 0
