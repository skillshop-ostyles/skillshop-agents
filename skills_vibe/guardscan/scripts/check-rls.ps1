[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ProjectDir
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$resolvedDir = Resolve-Path -LiteralPath $ProjectDir -ErrorAction Stop
$findings = @()
$excludeDirs = @('node_modules', '.next', 'dist', '.git', '.vercel')

Get-ChildItem $resolvedDir -Recurse -File -Include '*.sql' -ErrorAction SilentlyContinue | ForEach-Object {
    $relative = $_.FullName.Substring($resolvedDir.Length + 1)
    foreach ($excl in $excludeDirs) {
        if ($relative -match "^$excl[\\/]") { return }
    }

    $content = Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { return }

    $lines = $content -split '\r?\n'
    $lineNum = 1
    $inCreateTable = $false
    $createTableStart = 0
    $createTableName = ''
    $semicolons = 0
    $tableHasRLS = @{}

    foreach ($line in $lines) {
        # Track CREATE TABLE
        if ($line -match 'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(\S+)') {
            $createTableName = $Matches[1] -replace '["`\[\]]', ''
            $inCreateTable = $true
            $createTableStart = $lineNum
            $semicolons = if ($line.Trim().EndsWith(';')) { 1 } else { 0 }
        } elseif ($inCreateTable) {
            if ($line.Trim().EndsWith(';')) { $semicolons++ }
            if ($line -match '\);' -or $line.Trim() -eq ';') { $semicolons++ }
            if ($semicolons -ge 1 -and $line.Trim() -match '\);\s*$') {
                $inCreateTable = $false
            }
        }

        # Track RLS enablements
        if ($line -match 'ALTER\s+TABLE\s+(\S+)\s+ENABLE\s+ROW\s+LEVEL\s+SECURITY') {
            $rlsTable = $Matches[1] -replace '["`\[\]]', ''
            $tableHasRLS[$rlsTable] = $true
        }

        $lineNum++
    }

    # Detect service_role key usage (RLS bypass)
    if ($content -match 'service_role') {
        $serviceLines = @($lines | Select-String -Pattern 'service_role' -SimpleMatch)
        foreach ($match in $serviceLines) {
            $sLine = $match.LineNumber
            $sContent = $lines[$sLine - 1]
            $findings += @{
                impact = 'high'
                type = 'rls'
                file = $relative
                line = $sLine
                message = "service_role key used in code - bypasses all RLS policies"
                snippet = $sContent.Trim().Substring(0, [Math]::Min(70, $sContent.Trim().Length))
                incident = 'Moltbook July 2025  1.5M API keys exposed via missing RLS'
                confidence = 'proven'
            }
        }
    }
}

# Also scan source files for service_role usage
Get-ChildItem $resolvedDir -Recurse -File -Include '*.ts', '*.tsx', '*.js', '*.jsx' -ErrorAction SilentlyContinue | ForEach-Object {
    $relative = $_.FullName.Substring($resolvedDir.Length + 1)
    foreach ($excl in $excludeDirs) {
        if ($relative -match "^$excl[\\/]") { return }
    }
    $srcContent = Get-Content $_.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $srcContent) { return }
    if ($srcContent -match 'service_role') {
        $srcLines = Get-Content $_.FullName -Encoding UTF8 -ErrorAction SilentlyContinue
        $sLineNum = 1
        foreach ($sLine in $srcLines) {
            if ($sLine -match 'service_role') {
                $findings += @{
                    impact = 'high'
                    type = 'rls'
                    file = $relative
                    line = $sLineNum
                    message = "service_role key used in source code - bypasses all RLS policies"
                    snippet = $sLine.Trim().Substring(0, [Math]::Min(70, $sLine.Trim().Length))
                    incident = 'Moltbook July 2025  1.5M API keys exposed via missing RLS'
                    confidence = 'proven'
                }
            }
            $sLineNum++
        }
    }
}

# Re-scan for CREATE TABLE without matching RLS
$sqlFiles = Get-ChildItem $resolvedDir -Recurse -File -Include '*.sql' -ErrorAction SilentlyContinue
foreach ($sqlFile in $sqlFiles) {
    $sqlRelative = $sqlFile.FullName.Substring($resolvedDir.Length + 1)
    $content = Get-Content $sqlFile.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    $lines = $content -split '\r?\n'
    $lineNum = 1
    foreach ($line in $lines) {
        if ($line -match 'CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?(\S+)') {
            $tblName = $Matches[1] -replace '["`\[\]]', ''
            $tblSimple = $tblName -replace '^.+\.', ''
            $hasRLS = $false
            foreach ($key in $tableHasRLS.Keys) {
                $keySimple = $key -replace '^.+\.', ''
                if ($keySimple -eq $tblSimple) { $hasRLS = $true; break }
            }
            if (-not $hasRLS) {
                $findings += @{
                    impact = 'high'
                    type = 'rls'
                    file = $sqlRelative
                    line = $lineNum
                    message = "CREATE TABLE $tblSimple without ENABLE ROW LEVEL SECURITY"
                    snippet = $line.Trim().Substring(0, [Math]::Min(70, $line.Trim().Length))
                    incident = 'Moltbook July 2025  1.5M API keys exposed via missing RLS'
                    confidence = 'proven'
                }
            }
        }
        $lineNum++
    }
}

$result = @{
    check = 'rls'
    status = if ($findings.Count -gt 0) { 'fail' } else { 'pass' }
    findings = $findings
    summary = @{ total = $findings.Count; impact_high = $findings.Count; can_fix = $true }
}

Write-Output ($result | ConvertTo-Json -Depth 3)
