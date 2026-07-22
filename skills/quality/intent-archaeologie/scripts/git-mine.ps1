[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [Parameter(Mandatory = $true)]
    [string]$File,

    [string]$Symbol,

    [int]$MaxCommits = 200
)

$ErrorActionPreference = 'Stop'

# git gibt UTF-8 aus; ohne das hier liest PowerShell 5.1 die Bytes mit der
# System-Codepage und Umlaute/Sonderzeichen in Commit-Messages werden zu Mojibake.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir existiert nicht: $ProjectDir"
    exit 1
}

$isRepo = & git -C $ProjectDir rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0 -or $isRepo -ne 'true') {
    Write-Error "Kein Git-Repo: $ProjectDir"
    exit 1
}

if (-not (Test-Path -LiteralPath (Join-Path $ProjectDir $File))) {
    Write-Error "Datei existiert nicht: $File (in $ProjectDir)"
    exit 1
}

# --- 1 + 3. Commit-Historie + Ticket-IDs ---
# Eigene Feld-/Record-Trenner (Unit/Record Separator, 0x1f/0x1e) statt Newlines,
# da Commit-Bodies selbst mehrzeilig sein koennen.
$format = '%H%x1f%ad%x1f%an%x1f%s%x1f%b%x1e'
# PowerShell zerlegt die Ausgabe externer Programme automatisch zeilenweise in ein
# Array - mit -join wieder zu einem String zusammenfuegen, sonst zerreissen
# mehrzeilige Commit-Bodies unsere eigene 0x1e/0x1f-Record-Struktur.
$rawLines = & git -C $ProjectDir log --follow --date=short "--pretty=format:$format" -- $File 2>$null
$raw = if ($rawLines) { ($rawLines -join "`n") } else { '' }

$records = @()
if ($raw) {
    $records = @($raw -split [char]0x1e | Where-Object { $_.Trim() -ne '' })
}
$totalCount = $records.Count
$truncated = $totalCount -gt $MaxCommits

# git log liefert neueste zuerst. Bei Kuerzung: neueste $MaxCommits behalten,
# danach fuer die chronologische LLM-Analyse aeltest-zuerst sortieren.
$limited = if ($truncated) { $records[0..($MaxCommits - 1)] } else { $records }
[array]::Reverse($limited)

$ticketRegexJira = '[A-Z][A-Z0-9]+-\d+'
$ticketRegexGh = '#\d+'
$allTicketIds = New-Object System.Collections.Generic.List[string]
$commits = @()

foreach ($rec in $limited) {
    # Trim: an Rename-Uebergaengen fuegt "git log --follow" gelegentlich einen
    # stray Newline am Record-Anfang ein, der sonst das Hash-Feld verschiebt.
    $fields = $rec.Trim() -split [char]0x1f
    $hash = $fields[0].Trim()
    $shortHash = $hash.Substring(0, [Math]::Min(7, $hash.Length))
    $date = $fields[1].Trim()
    $author = $fields[2].Trim()
    $subject = $fields[3].Trim()
    $body = if ($fields.Count -gt 4) { ($fields[4..($fields.Count - 1)] -join [string][char]0x1f).Trim() } else { '' }

    $combinedText = "$subject`n$body"
    $ticketsHere = New-Object System.Collections.Generic.List[string]
    foreach ($m in [regex]::Matches($combinedText, $ticketRegexJira)) { $ticketsHere.Add($m.Value) }
    foreach ($m in [regex]::Matches($combinedText, $ticketRegexGh)) { $ticketsHere.Add($m.Value) }
    $ticketsHere = @($ticketsHere | Select-Object -Unique)
    foreach ($t in $ticketsHere) { $allTicketIds.Add($t) }

    $commits += [ordered]@{
        hash    = $shortHash
        date    = $date
        author  = $author
        subject = $subject
        body    = $body
        tickets = $ticketsHere
    }
}
$ticketIdsUnique = @($allTicketIds | Select-Object -Unique)

# --- 2. Symbol-Log (optional) ---
$symbolLogAvailable = $false
if ($Symbol) {
    $symbolOutput = & git -C $ProjectDir log "-L:${Symbol}:${File}" --oneline 2>$null
    if ($LASTEXITCODE -eq 0 -and $symbolOutput) { $symbolLogAvailable = $true }
}

# --- 4. Blame-Aggregation ---
$blameRaw = & git -C $ProjectDir blame --line-porcelain -- $File 2>$null
$byAuthor = @{}
$byCommit = @{}
if ($blameRaw) {
    $currentHash = $null
    $currentAuthor = $null
    foreach ($line in $blameRaw) {
        if ($line -match '^[0-9a-f]{40} \d+ \d+') {
            $currentHash = $line.Substring(0, 40)
        } elseif ($line.StartsWith('author ')) {
            $currentAuthor = $line.Substring(7)
        } elseif ($line.StartsWith("`t")) {
            if ($currentAuthor) {
                if (-not $byAuthor.ContainsKey($currentAuthor)) { $byAuthor[$currentAuthor] = 0 }
                $byAuthor[$currentAuthor] += 1
            }
            if ($currentHash) {
                $shortH = $currentHash.Substring(0, 7)
                if (-not $byCommit.ContainsKey($shortH)) { $byCommit[$shortH] = 0 }
                $byCommit[$shortH] += 1
            }
        }
    }
}
$byAuthorList = @($byAuthor.GetEnumerator() | Sort-Object -Property Value -Descending | ForEach-Object { [ordered]@{ author = $_.Key; lines = $_.Value } })
$byCommitList = @($byCommit.GetEnumerator() | Sort-Object -Property Value -Descending | Select-Object -First 10 | ForEach-Object { [ordered]@{ hash = $_.Key; lines = $_.Value } })

# --- Ergebnis ---
$result = [ordered]@{
    file               = $File
    symbol             = if ($Symbol) { $Symbol } else { $null }
    symbolLogAvailable = $symbolLogAvailable
    commits            = $commits
    ticketIds          = $ticketIdsUnique
    blame              = [ordered]@{
        byAuthor = $byAuthorList
        byCommit = $byCommitList
    }
    truncated          = $truncated
}

Write-Output (ConvertTo-Json $result -Depth 6)

$commitCount = $commits.Count
$dateRange = if ($commitCount -gt 0) { "$($commits[0].date) bis $($commits[-1].date)" } else { 'keine Historie' }
$topAuthors = ($byAuthorList | Select-Object -First 3 | ForEach-Object { "$($_.author) ($($_.lines))" }) -join ', '

Write-Output "`n=== INTENT-MINE: $File ==="
Write-Output "  Commits: $commitCount$(if ($truncated) { " (gekuerzt auf $MaxCommits von $totalCount)" })"
Write-Output "  Zeitspanne: $dateRange"
Write-Output "  Top-Autoren (Blame): $(if ($topAuthors) { $topAuthors } else { 'keine Blame-Daten' })"
Write-Output "  Ticket-IDs gefunden: $($ticketIdsUnique.Count)"
if ($Symbol) {
    Write-Output "  Symbol '$Symbol': $(if ($symbolLogAvailable) { 'Log verfuegbar' } else { 'nicht gefunden, Analyse faellt auf Datei-Ebene zurueck' })"
}
