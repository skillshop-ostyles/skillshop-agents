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

# git outputs UTF-8; without this, PowerShell 5.1 reads the bytes with the
# system codepage and umlauts/special characters in commit messages become Mojibake.
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir does not exist: $ProjectDir"
    exit 1
}

$isRepo = & git -C $ProjectDir rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -ne 0 -or $isRepo -ne 'true') {
    Write-Error "Not a git repo: $ProjectDir"
    exit 1
}

if (-not (Test-Path -LiteralPath (Join-Path $ProjectDir $File))) {
    Write-Error "File does not exist: $File (in $ProjectDir)"
    exit 1
}

# -- 1 + 3. Commit history + Ticket IDs --
# Custom field/record separators (Unit/Record Separator, 0x1f/0x1e) instead of newlines,
# since commit bodies themselves can be multi-line.
$format = '%H%x1f%ad%x1f%an%x1f%s%x1f%b%x1e'
# PowerShell splits external program output line by line into an
# array - use -join to reassemble into a single string, otherwise
# multi-line commit bodies would break our 0x1e/0x1f record structure.
$rawLines = & git -C $ProjectDir log --follow --date=short "--pretty=format:$format" '--' $File 2>$null
$raw = if ($rawLines) { ($rawLines -join "`n") } else { '' }

$records = @()
if ($raw) {
    $records = @($raw -split [char]0x1e | Where-Object { $_.Trim() -ne '' })
}
$totalCount = $records.Count
$truncated = $totalCount -gt $MaxCommits

# git log returns newest first. When truncating: keep newest $MaxCommits,
# then sort oldest-first for chronological LLM analysis.
$limited = if ($truncated) { $records[0..($MaxCommits - 1)] } else { $records }
[array]::Reverse($limited)

$ticketRegexJira = '[A-Z][A-Z0-9]+-\d+'
$ticketRegexGh = '#\d+'
$allTicketIds = New-Object System.Collections.Generic.List[string]
$commits = @()

foreach ($rec in $limited) {
    # Trim: at rename boundaries, "git log -follow" occasionally inserts a
    # stray newline at the record start, which would otherwise shift the hash field.
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

# -- 2. Symbol-Log (optional) --
$symbolLogAvailable = $false
if ($Symbol) {
    $symbolOutput = & git -C $ProjectDir log "-L:${Symbol}:${File}" '--oneline' 2>$null
    if ($LASTEXITCODE -eq 0 -and $symbolOutput) { $symbolLogAvailable = $true }
}

# -- 4. Blame-Aggregation --
$blameRaw = & git -C $ProjectDir blame '--line-porcelain' '--' $File 2>$null
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

# -- Ergebnis --
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
$dateRange = if ($commitCount -gt 0) { "$($commits[0].date) to $($commits[-1].date)" } else { 'no history' }
$topAuthors = ($byAuthorList | Select-Object -First 3 | ForEach-Object { "$($_.author) ($($_.lines))" }) -join ', '

Write-Output "`n=== INTENT-MINE: $File ==="
Write-Output "  Commits: $commitCount$(if ($truncated) { " (truncated to $MaxCommits of $totalCount)" })"
Write-Output "  Time span: $dateRange"
Write-Output "  Top authors (blame): $(if ($topAuthors) { $topAuthors } else { 'no blame data' })"
Write-Output "  Ticket IDs found: $($ticketIdsUnique.Count)"
if ($Symbol) {
    Write-Output "  Symbol '$Symbol': $(if ($symbolLogAvailable) { 'Log available' } else { 'not found, analysis falls back to file level' })"
}
