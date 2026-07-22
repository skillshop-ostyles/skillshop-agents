[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [Parameter(Mandatory = $true)]
    [string]$Candidates,

    [string]$CoverageFile,
    [string]$LogDir
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir existiert nicht: $ProjectDir"
    exit 1
}
if (-not (Test-Path -LiteralPath $Candidates)) {
    Write-Error "Candidates-Datei existiert nicht: $Candidates"
    exit 1
}

# reachability.ps1 gibt JSON + Konsolen-Zusammenfassung aus (BIBEL-Output-Contract);
# beim Umleiten in eine Datei landet beides drin - nur den JSON-Teil vor der
# "=== ..."-Markierung parsen.
$rawLines = Get-Content -LiteralPath $Candidates -ErrorAction SilentlyContinue
$raw = [string]::Join("`n", $rawLines)
$jsonPart = ($raw -split "`n=== ")[0]
try {
    $inputData = $jsonPart | ConvertFrom-Json
} catch {
    Write-Error "Candidates-Datei enthaelt kein valides JSON (Ausgabe von reachability.ps1 erwartet)."
    exit 1
}

# --- Coverage laden (Istanbul coverage-summary.json ODER lcov.info) ---
$coverageByFile = @{}
$coverageNote = $null
if ($CoverageFile) {
    if (-not (Test-Path -LiteralPath $CoverageFile)) {
        Write-Error "CoverageFile existiert nicht: $CoverageFile"
        exit 1
    }
    $covRaw = Get-Content -LiteralPath $CoverageFile -Raw -ErrorAction SilentlyContinue
    if ($CoverageFile -match '(?i)\.json$') {
        try {
            $covJson = $covRaw | ConvertFrom-Json
            foreach ($prop in $covJson.PSObject.Properties) {
                if ($prop.Name -eq 'total') { continue }
                $lines = $prop.Value.lines
                if ($lines) {
                    $coverageByFile[$prop.Name] = [ordered]@{ covered = $lines.covered; total = $lines.total }
                }
            }
        } catch {
            $coverageNote = 'Coverage-JSON nicht als Istanbul-Format erkannt.'
        }
    } elseif ($CoverageFile -match '(?i)\.info$' -or $covRaw -match '(?m)^SF:') {
        $currentFile = $null
        $lf = 0; $lh = 0
        foreach ($rawLine in ($covRaw -split "`n")) {
            $line = $rawLine.TrimEnd("`r")
            if ($line.StartsWith('SF:')) { $currentFile = ($line.Substring(3).Trim() -replace '\\', '/') }
            elseif ($line.StartsWith('LF:')) { $lf = [int]$line.Substring(3) }
            elseif ($line.StartsWith('LH:')) { $lh = [int]$line.Substring(3) }
            elseif ($line -eq 'end_of_record' -and $currentFile) {
                $coverageByFile[$currentFile] = [ordered]@{ covered = $lh; total = $lf }
                $currentFile = $null; $lf = 0; $lh = 0
            }
        }
    } else {
        $coverageNote = 'Coverage-Format nicht erkannt (weder Istanbul-JSON noch lcov.info).'
    }
}

function Get-CoverageFor($relFile) {
    $normalized = $relFile -replace '\\', '/'
    foreach ($key in $coverageByFile.Keys) {
        $normKey = $key -replace '\\', '/'
        if ($normKey -eq $normalized -or $normKey.EndsWith("/$normalized") -or $normalized.EndsWith("/$normKey")) {
            return $coverageByFile[$key]
        }
    }
    return $null
}

# --- Logs durchsuchen (Symbolname-Grep = Lebens-Evidenz) ---
$logContent = ''
if ($LogDir) {
    if (-not (Test-Path -LiteralPath $LogDir)) {
        Write-Error "LogDir existiert nicht: $LogDir"
        exit 1
    }
    $logFiles = @(Get-ChildItem -LiteralPath $LogDir -Recurse -File -ErrorAction SilentlyContinue)
    if ($logFiles.Count -gt 0) {
        $parts = @($logFiles | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw -ErrorAction SilentlyContinue })
        $logContent = [string]::Join("`n", $parts)
    }
}

function Get-LogHits($symbol) {
    if (-not $logContent) { return $null }
    $pattern = "\b$([regex]::Escape($symbol))\b"
    return ([regex]::Matches($logContent, $pattern)).Count
}

# --- Anreichern ---
$enrichedSymbols = @(
    foreach ($c in $inputData.symbolCandidates) {
        [ordered]@{
            file         = $c.file
            line         = $c.line
            symbol       = $c.symbol
            externalRefs = $c.externalRefs
            coverage     = Get-CoverageFor $c.file
            logHits      = Get-LogHits $c.symbol
        }
    }
)
$enrichedFiles = @(
    foreach ($c in $inputData.fileCandidates) {
        [ordered]@{
            file                = $c.file
            referencedBy        = $c.referencedBy
            isEntryPointPattern = $c.isEntryPointPattern
            coverage            = Get-CoverageFor $c.file
        }
    }
)

$result = [ordered]@{
    symbolCandidates = $enrichedSymbols
    fileCandidates   = $enrichedFiles
    coverageNote     = $coverageNote
    logDirUsed       = [bool]$LogDir
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== EVIDENCE ==="
Write-Output "  Symbol-Kandidaten angereichert: $($enrichedSymbols.Count)"
Write-Output "  Datei-Kandidaten angereichert: $($enrichedFiles.Count)"
if ($coverageNote) { Write-Output "  Coverage: $coverageNote" }
if ($LogDir) { Write-Output "  Log-Verzeichnis durchsucht: $LogDir" }
