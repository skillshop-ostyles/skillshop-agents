[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string]$Extensions = "*.ts,*.js"
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

$extList = $Extensions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }

$scannedFiles = 0
$schemas = @{}      # field -> { declaredType, declaredNullable }
$schemaFile = $null # track which file declared the schema
$allUsages = @()    # { field, file, line, usageType, usedType, usedNullable }

function Add-Usage($field, $file, $line, $usageType, $usedType, $usedNullable) {
    $script:allUsages += @{
        field = $field
        file = $file
        line = $line
        usageType = $usageType
        usedType = $usedType
        usedNullable = $usedNullable
    }
}

function Get-UsedType($expr) {
    $e = $expr.Trim()
    if ($e -match '^parseInt\(' -or $e -match '^Number\(' -or $e -match '^parseFloat\(') { return 'number' }
    if ($e -match '^".*"$' -or $e -match "^'.*'$") { return 'string' }
    if ($e -match '^\d+\.?\d*$') { return 'number' }
    if ($e -match '^true$|^false$') { return 'boolean' }
    if ($e -match '^null$') { return 'null' }
    if ($e -match '^undefined$') { return 'undefined' }
    if ($e -match '^\[\s*\]$') { return 'array' }
    if ($e -match '^\{\s*\}$') { return 'object' }
    if ($e -match 'body\.\w+' -or $e -match 'req\.body\.\w+') { return 'string' }
    if ($e -match '\.toString\(\)') { return 'string' }
    if ($e -match '\|\|') { return 'mixed' }
    return 'inferred'
}

function Get-UsedNullable($expr) {
    $e = $expr.Trim()
    if ($e -match '\|\s*(undefined|null)' -or $e -match '^\s*(undefined|null)\s*\|') { return $true }
    if ($e -match 'body\.\w+' -or $e -match 'req\.body\.\w+') { return $true }
    if ($e -eq 'undefined' -or $e -eq 'null') { return $true }
    if ($e -match '\|\|') { return $true }
    return $false
}

function Get-ObjectProperties($line) {
    $props = @()
    $objMatch = [regex]::Match($line, '\{(.*)\}')
    if (-not $objMatch.Success) { return $props }
    $inner = $objMatch.Groups[1].Value
    $parts = $inner -split ','
    foreach ($part in $parts) {
        $part = $part.Trim()
        if (-not $part) { continue }
        if ($part -match '^(\w+)\s*:\s*(.+)$') {
            $props += @{ key = $Matches[1]; value = $Matches[2].Trim() }
        } elseif ($part -match '^(\w+)$') {
            $props += @{ key = $Matches[1]; value = $Matches[1] }
        }
    }
    return $props
}

$varDefs = @{} # varName -> { type, nullable, sourceLine }

foreach ($ext in $extList) {
    Get-ChildItem -LiteralPath $ProjectDir -Recurse -Filter $ext -File -ErrorAction SilentlyContinue | Where-Object {
        $_.FullName -notmatch 'node_modules|\.git|venv|bin|obj|__pycache__|dist|build'
    } | ForEach-Object {
        $fp = $_.FullName
        $content = Get-Content -LiteralPath $fp -Raw -ErrorAction SilentlyContinue
        if (-not $content) { return }
        $script:scannedFiles++

        $rel = $fp.Substring($ProjectDir.Length).TrimStart('\')
        $lines = $content -split "`r`n|`n"

        # ---- Schema detection ----
        $inInterface = $null
        $currentFields = @()
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $trimmed = $line.Trim()

            if ($trimmed -match '^interface\s+(\w+)\s*\{') {
                $inInterface = $Matches[1]
                $currentFields = @()
                continue
            }

            if ($null -ne $inInterface) {
                if ($trimmed -match '^\}') {
                    foreach ($f in $currentFields) {
                        $script:schemas[$f.name] = @{
                            declaredType = $f.type
                            declaredNullable = $f.nullable
                        }
                        $script:schemaFile = $rel
                    }
                    $inInterface = $null
                    $currentFields = @()
                    continue
                }
                $propMatch = [regex]::Match($trimmed, '^\s*(\w+)\s*(\??)\s*:\s*(.+?)\s*[;,]?\s*$')
                if ($propMatch.Success) {
                    $fname = $propMatch.Groups[1].Value
                    $optional = $propMatch.Groups[2].Value -eq '?'
                    $typeRaw = $propMatch.Groups[3].Value.Trim()
                    $nullable = $optional -or $typeRaw -match '\|\s*(null|undefined)' -or $typeRaw -match '^\s*(null|undefined)\s*\|'
                    $cleanType = $typeRaw -replace '\s*\|\s*(null|undefined)\s*', '' -replace '^\s*(null|undefined)\s*\|\s*', ''
                    $cleanType = $cleanType.Trim()
                    $currentFields += @{ name = $fname; type = $cleanType; nullable = $nullable }
                }
            }
        }

        # ---- Usage detection ----
        $varDefs = @{}
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $lineNum = $i + 1
            $trimmed = $line.Trim()

            # Track variable definitions: const x = <expr>
            $varMatch = [regex]::Match($trimmed, '^(?:const|let|var)\s+(\w+)\s*=\s*(.+?)\s*[;]?\s*$')
            if ($varMatch.Success) {
                $vname = $varMatch.Groups[1].Value
                $vexpr = $varMatch.Groups[2].Value.Trim()
                $vType = Get-UsedType $vexpr
                $vNullable = Get-UsedNullable $vexpr
                $varDefs[$vname] = @{ type = $vType; nullable = $vNullable; expr = $vexpr }

                # If this is a body.field access, register that usage
                $bodyFieldMatch = [regex]::Match($vexpr, '(?:body|req\.body)\.(\w+)')
                if ($bodyFieldMatch.Success -and -not ($vexpr -match '\|\|')) {
                    $bfield = $bodyFieldMatch.Groups[1].Value
                    Add-Usage $bfield $rel $lineNum 'body-access' 'inferred' $false
                }

                # If this is parseInt(body.field), register body access
                $piMatch = [regex]::Match($vexpr, 'parseInt\((.+?)\)')
                if ($piMatch.Success) {
                    $innerExpr = $piMatch.Groups[1].Value.Trim()
                    $innerBody = [regex]::Match($innerExpr, '(?:body|req\.body)\.(\w+)')
                    if ($innerBody.Success) {
                        Add-Usage $innerBody.Groups[1].Value $rel $lineNum 'type-coercion' 'string' $true
                    }
                }

                # If the expr has || undefined / || null, register the field as nullable
                $nullishMatch = [regex]::Match($vexpr, '(?:body|req\.body)\.(\w+)\s*\|\|\s*(undefined|null)')
                if ($nullishMatch.Success) {
                    Add-Usage $nullishMatch.Groups[1].Value $rel $lineNum 'nullish-coalescing' 'mixed' $true
                }

                continue
            }

            # Object literal assignments (return { ... } or const x = { ... })
            if ($trimmed -match '\{') {
                $props = Get-ObjectProperties $trimmed
                foreach ($prop in $props) {
                    $usageType = 'object-assignment'
                    if ($trimmed -match '^return\s') { $usageType = 'response-return' }
                    if ($trimmed -match '\.create\(' -or $trimmed -match '\.update\(') { $usageType = 'orm-write' }

                    # Resolve value to determine actual type/nullability
                    $val = $prop.value
                    $usedType = Get-UsedType $val
                    $usedNullable = Get-UsedNullable $val

                    # If value is a variable name, look up its definition
                    if ($varDefs.ContainsKey($val)) {
                        $vd = $varDefs[$val]
                        if ($vd.type -ne 'inferred') { $usedType = $vd.type }
                        if ($vd.nullable) { $usedNullable = $true }
                        # If the var's expr contains || undefined, mark nullable
                        if ($vd.expr -match '\|\|') { $usedNullable = $true }
                    }

                    # If value is body.field, register body access (type from schema cast)
                    if ($val -match '(?:body|req\.body)\.(\w+)') {
                        $usedType = 'inferred'
                        $usedNullable = $false
                        $bf = $Matches[1]
                        Add-Usage $bf $rel $lineNum 'body-access' 'inferred' $false
                    }

                    Add-Usage $prop.key $rel $lineNum $usageType $usedType $usedNullable
                }
            }

            # FormData / form parsing patterns
            if ($trimmed -match 'new\s+FormData\(' -or $trimmed -match 'form\.(?:get|append)\(') {
                $formFieldMatch = [regex]::Matches($trimmed, '["''](\w+)["'']')
                foreach ($ff in $formFieldMatch) {
                    Add-Usage $ff.Groups[1].Value $rel $lineNum 'form-parsing' 'string' $true
                }
            }
        }
    }
}

# ---- Build contracts ----
$contracts = @()
$discrepancyCount = 0

foreach ($field in $schemas.Keys) {
    $decl = $schemas[$field]
    $matchingUsages = $allUsages | Where-Object { $_.field -eq $field }
    $sites = @($matchingUsages)

    $siteEntries = @()
    $hasDiscrepancy = $false

    foreach ($site in $sites) {
        $discrepant = $false
        $effectiveType = $site.usedType
        $effectiveNullable = $site.usedNullable

        if ($site.usageType -eq 'type-coercion') {
            $effectiveType = 'string'
            $effectiveNullable = $true
        }

        if ($effectiveNullable -and -not $decl.declaredNullable) {
            $discrepant = $true
        }
        if ($effectiveType -ne 'inferred' -and $effectiveType -ne 'mixed' -and $effectiveType -ne $decl.declaredType) {
            $discrepant = $true
        }

        if ($discrepant) { $hasDiscrepancy = $true }

        $siteEntries += @{
            file = $site.file
            line = $site.line
            usageType = $site.usageType
            usedType = $effectiveType
            usedNullable = $effectiveNullable
        }
    }

    $contracts += @{
        field = $field
        declaredType = $decl.declaredType
        declaredNullable = $decl.declaredNullable
        usageSites = $siteEntries
        hasDiscrepancy = $hasDiscrepancy
    }

    if ($hasDiscrepancy) { $discrepancyCount++ }
}

$result = @{
    contracts = $contracts
    summary = @{
        filesScanned = $script:scannedFiles
        schemasFound = if ($schemas.Count -gt 0) { 1 } else { 0 }
        fieldsFound = $schemas.Count
        usageSitesFound = $allUsages.Count
        discrepanciesFound = $discrepancyCount
    }
}

# ---- Console summary ----
Write-Output "=== Data Contract Scan Complete ==="
Write-Output "  Files scanned: $($result.summary.filesScanned)"
Write-Output "  Schemas found: $($result.summary.schemasFound)"
Write-Output "  Fields found in schemas: $($result.summary.fieldsFound)"
Write-Output "  Usage sites: $($result.summary.usageSitesFound)"
Write-Output "  Discrepancies detected: $($result.summary.discrepanciesFound)"
foreach ($c in $contracts) {
    if ($c.hasDiscrepancy) {
        Write-Output "  [!] $($c.field): declared $($c.declaredType) (nullable=$($c.declaredNullable)) - $($c.usageSites.Count) usage(s) with contract break"
    } else {
        Write-Output "  [OK] $($c.field): declared $($c.declaredType) (nullable=$($c.declaredNullable)) - $($c.usageSites.Count) usage(s), clean"
    }
}

Write-Output ($result | ConvertTo-Json -Depth 5)
exit 0
