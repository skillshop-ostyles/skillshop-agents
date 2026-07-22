[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$LogDir,

    [int]$MaxLinesPerFile = 200000,
    [int]$SampleSize = 20
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $LogDir)) {
    Write-Error "LogDir existiert nicht: $LogDir"
    exit 1
}

$logFiles = @(
    Get-ChildItem -LiteralPath $LogDir -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in '.log', '.txt', '.jsonl', '.json' }
)

if ($logFiles.Count -eq 0) {
    Write-Error "Keine Log-Dateien (*.log/*.txt/*.jsonl/*.json) gefunden in: $LogDir"
    exit 1
}

$tsRegex = '\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:?\d{2})?'
$uuidRegex = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
$levelRegex = '(?i)\b(ERROR|WARNING|WARN|INFO|DEBUG)\b'
$emailRegex = '[\w.+\-]+@[\w\-]+\.[\w.\-]+'

# Aggressive Normalisierung fuer den Gruppierungs-Key (Zeitstempel/UUID/Zahlen/
# Quoted-Strings raus, damit gleichartige Zeilen auf ein Muster zusammenfallen).
function Get-PatternKey($text) {
    $s = $text
    # PII-Maskierung zuerst: Nicht-Scope verlangt Maskierung "in ALLEN Ausgaben",
    # nicht nur in den Samples - der Pattern-Key landet als "pattern"-Feld direkt
    # im JSON und potenziell wortwoertlich im LLM-Report.
    $s = $s -replace $emailRegex, '<EMAIL>'
    $s = $s -replace $tsRegex, '<TS>'
    $s = $s -replace $uuidRegex, '<UUID>'
    $s = $s -replace '"[^"]*"', '<STR>'
    $s = $s -replace "'[^']*'", '<STR>'
    # Ohne \b: "9" und "m" in "39ms" sind beides Wortzeichen, \b\d+\b matcht dort
    # nicht (kein Wortgrenzen-Uebergang) - Zahlen mit direkt angehaengter Einheit
    # (39ms, 5000x) wuerden sonst nicht normalisiert und Muster faelschlich spalten.
    $s = $s -replace '\d+', '<N>'
    return $s.Trim()
}

# Gezielte PII-Maskierung fuer gespeicherte Beispiel-Zeilen (bleibt sonst lesbar).
function Get-MaskedSample($text) {
    $s = $text
    $s = $s -replace $emailRegex, '<EMAIL>'
    $s = $s -replace '\d{6,}', '<NUM>'
    return $s
}

function Get-Level($text) {
    $m = [regex]::Match($text, $levelRegex)
    if ($m.Success) { return $m.Value.ToUpper() }
    return $null
}

function Get-Timestamp($text) {
    $m = [regex]::Match($text, $tsRegex)
    if ($m.Success) {
        try { return [datetime]::Parse($m.Value).ToString('o') } catch { return $null }
    }
    return $null
}

$totalLines = 0
$truncated = $false
$patternData = [ordered]@{}

foreach ($file in $logFiles) {
    $allLines = @(Get-Content -LiteralPath $file.FullName -ErrorAction SilentlyContinue)
    $useLines = $allLines
    if ($allLines.Count -gt $MaxLinesPerFile) {
        $useLines = $allLines[0..($MaxLinesPerFile - 1)]
        $truncated = $true
    }

    # Format-Erkennung: die ersten nicht-leeren Zeilen als JSON testen.
    $probeLines = @($useLines | Where-Object { $_.Trim() -ne '' } | Select-Object -First 5)
    $jsonOk = 0
    foreach ($p in $probeLines) {
        try { [void]([string]$p | ConvertFrom-Json); $jsonOk++ } catch {}
    }
    $isJsonLines = ($probeLines.Count -gt 0 -and $jsonOk -eq $probeLines.Count)

    foreach ($rawLine in $useLines) {
        $line = [string]$rawLine
        if ($line.Trim() -eq '') { continue }
        $totalLines++

        $text = $line
        $level = $null
        $ts = $null

        if ($isJsonLines) {
            try {
                $lineObj = $line | ConvertFrom-Json
                if ($lineObj.message) { $text = [string]$lineObj.message }
                elseif ($lineObj.msg) { $text = [string]$lineObj.msg }
                elseif ($lineObj.log) { $text = [string]$lineObj.log }
                if ($lineObj.level) { $level = ([string]$lineObj.level).ToUpper() }
                $tsField = $null
                if ($lineObj.time) { $tsField = $lineObj.time }
                elseif ($lineObj.timestamp) { $tsField = $lineObj.timestamp }
                elseif ($lineObj.ts) { $tsField = $lineObj.ts }
                if ($tsField) { try { $ts = [datetime]::Parse([string]$tsField).ToString('o') } catch {} }
            } catch {
                # Einzelne Zeile weicht vom Datei-Format ab - als Rohtext weiterverarbeiten.
            }
        }

        if (-not $level) { $level = Get-Level $text }
        if (-not $ts) { $ts = Get-Timestamp $text }

        $key = Get-PatternKey $text
        if (-not $patternData.Contains($key)) {
            $patternData[$key] = [ordered]@{
                pattern = $key
                count   = 0
                levels  = @{}
                first   = $null
                last    = $null
                samples = New-Object System.Collections.Generic.List[string]
            }
        }
        $entry = $patternData[$key]
        $entry.count += 1
        if ($level) {
            if (-not $entry.levels.ContainsKey($level)) { $entry.levels[$level] = 0 }
            $entry.levels[$level] += 1
        }
        if ($ts) {
            if (-not $entry.first -or $ts -lt $entry.first) { $entry.first = $ts }
            if (-not $entry.last -or $ts -gt $entry.last) { $entry.last = $ts }
        }
        if ($entry.samples.Count -lt $SampleSize) {
            $entry.samples.Add((Get-MaskedSample $text))
        }
    }
}

$patterns = @(
    foreach ($entry in $patternData.Values) {
        $dominantLevel = $null
        if ($entry.levels.Count -gt 0) {
            $dominantLevel = ($entry.levels.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 1).Key
        }
        [ordered]@{
            pattern = $entry.pattern
            count   = $entry.count
            level   = $dominantLevel
            first   = $entry.first
            last    = $entry.last
            samples = $entry.samples.ToArray()
        }
    }
)

$topPatterns = @($patterns | Sort-Object -Property count -Descending | Select-Object -First 50)
$errorPatterns = @($patterns | Where-Object { $_.level -eq 'ERROR' } | Sort-Object -Property count -Descending | Select-Object -First 20)
$errorLineCount = ($patterns | Where-Object { $_.level -eq 'ERROR' } | Measure-Object -Property count -Sum).Sum
if (-not $errorLineCount) { $errorLineCount = 0 }
$errorRate = if ($totalLines -gt 0) { [Math]::Round($errorLineCount / $totalLines, 4) } else { 0 }

$result = [ordered]@{
    files         = $logFiles.Count
    totalLines    = $totalLines
    truncated     = $truncated
    patterns      = $topPatterns
    errorPatterns = $errorPatterns
    errorRate     = $errorRate
}

Write-Output (ConvertTo-Json $result -Depth 8)

Write-Output "`n=== LOG-INGEST ==="
Write-Output "  Dateien: $($logFiles.Count), Zeilen gesamt: $totalLines$(if ($truncated) { ' (gekuerzt)' })"
Write-Output "  Muster gesamt: $($patternData.Count), Top-Muster gezeigt: $($topPatterns.Count)"
Write-Output "  Fehlerquote: $([Math]::Round($errorRate * 100, 2))%"
