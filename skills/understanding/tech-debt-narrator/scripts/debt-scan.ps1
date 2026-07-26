[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [Parameter(Mandatory = $false)]
    [string]$Extensions = "*.ts,*.tsx,*.js,*.jsx,*.py,*.cs,*.go,*.java,*.rb,*.php",

    [Parameter(Mandatory = $false)]
    [string[]]$Exclude = @()
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Validate target path exists
if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir '$ProjectDir' does not exist."
    exit 1
}

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

# Parse extensions into an array
$extList = $Extensions.Split(',', [StringSplitOptions]::TrimEntries)

# Build file list
$files = Get-ChildItem -Path $ProjectDir -Recurse -File -Include $extList `
    | Where-Object { -not $_.Directory.FullName.StartsWith((Join-Path $ProjectDir '.git')) }

# Apply Exclude filters
foreach ($exPattern in $Exclude) {
    $files = $files | Where-Object { $_.FullName -notlike $exPattern }
}

# Regex patterns per debt type
$suppressPatterns = @(
    'eslint-disable',
    'ts-ignore',
    'ts-expect-error',
    '# noqa',
    '@SuppressWarnings',
    '@ts-nocheck'
)
$suppressRegex = "($($suppressPatterns -join '|'))"

$todoRegex = '\b(TODO|FIXME|HACK|XXX|Workaround|BUG)\b'

$emptyCatchPatterns = @(
    'catch\s*\(\s*\w+\s*\)\s*\{\s*\}',
    'catch\s*\{\s*\}',
    'except\s+\w+\s*:\s*pass',
    'except\s*:\s*pass'
)
$emptyCatchRegex = "($($emptyCatchPatterns -join '|'))"

$workaroundPatterns = @(
    'typeof\s+\w+\s*===\s*["'']undefined["'']',
    'typeof\s+\w+\s*==\s*["'']undefined["'']'
)
$workaroundRegex = "($($workaroundPatterns -join '|'))"

$legacyLibraries = @(
    'from\s+[''"]moment[''"]',
    'from\s+[''"]lodash[''"]',
    'from\s+[''"]underscore[''"]',
    'from\s+[''"]request[''"]',
    'require\([''"]moment[''"]\)',
    'require\([''"]lodash[''"]\)',
    'require\([''"]underscore[''"]\)',
    'require\([''"]request[''"]\)',
    'import\s+.*\s+from\s+[''"]moment[''"]',
    'import\s+.*\s+from\s+[''"]lodash[''"]',
    'import\s+.*\s+from\s+[''"]underscore[''"]',
    'import\s+.*\s+from\s+[''"]request[''"]',
    'axios\.(get|post|put|delete|patch|request)\s*\([''"]https?://\d+\.\d+\.\d+\.\d+'
)
$legacyRegex = "($($legacyLibraries -join '|'))"

$typeLoosenPatterns = @(
    'as\s+any',
    '<\w+>\s*\([^)]+\)\s*as\s+\w+',
    '\/\/\s*@ts-ignore'
)
$typeLoosenRegex = "($($typeLoosenPatterns -join '|'))"

function Get-FileAgeDays {
    param([string]$FilePath)
    try {
        $relPath = [System.IO.Path]::GetRelativePath((Get-Item $ProjectDir).FullName, $FilePath)
        $gitDir = Join-Path $ProjectDir '.git'
        if (Test-Path $gitDir) {
            $timestamp = git -C $ProjectDir log -1 --format="%ct" -- $relPath 2>$null
            if ($timestamp -and $timestamp -match '^\d+$') {
                $commitTime = [DateTimeOffset]::FromUnixTimeSeconds([int64]$timestamp)
                return [math]::Max(0, [int]([DateTime]::UtcNow - $commitTime.UtcDateTime).TotalDays)
            }
        }
    } catch {
        # git not available or not a git repo
    }
    return $null
}

$debts = @()
$counts = @{
    suppress     = 0
    todo         = 0
    emptyCatch   = 0
    workaround   = 0
    legacy       = 0
    typeLoosen   = 0
}

foreach ($file in $files) {
    $content = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    $lines = $content -split '\r?\n'
    $ageDays = Get-FileAgeDays -FilePath $file.FullName

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        $lineNum = $i + 1

        # Suppress comments
        if ($line -match $suppressRegex) {
            $debts += @{
                file    = $file.FullName
                line    = $lineNum
                type    = 'suppress'
                text    = $line.Trim()
                ageDays = $ageDays
                severity = if ($line -match '@ts-nocheck' -or $line -match 'eslint-disable\s*$') { 'high' } else { 'medium' }
            }
            $counts['suppress']++
        }

        # TODO / FIXME / HACK / XXX / Workaround / BUG
        if ($line -match $todoRegex) {
            # Skip if already caught as suppress
            if ($line -notmatch $suppressRegex) {
                $debts += @{
                    file    = $file.FullName
                    line    = $lineNum
                    type    = 'todo'
                    text    = $line.Trim()
                    ageDays = $ageDays
                    severity = 'medium'
                }
                $counts['todo']++
            }
        }

        # Empty catch blocks
        if ($line -match $emptyCatchRegex) {
            $debts += @{
                file    = $file.FullName
                line    = $lineNum
                type    = 'empty-catch'
                text    = $line.Trim()
                ageDays = $ageDays
                severity = if ($line -match 'except\s*\w*\s*:\s*pass') { 'high' } else { 'medium' }
            }
            $counts['emptyCatch']++
        }

        # Workaround patterns
        if ($line -match $workaroundRegex) {
            $debts += @{
                file    = $file.FullName
                line    = $lineNum
                type    = 'workaround'
                text    = $line.Trim()
                ageDays = $ageDays
                severity = 'medium'
            }
            $counts['workaround']++
        }

        # Legacy imports
        if ($line -match $legacyRegex) {
            $debts += @{
                file    = $file.FullName
                line    = $lineNum
                type    = 'legacy'
                text    = $line.Trim()
                ageDays = $ageDays
                severity = 'medium'
            }
            $counts['legacy']++
        }

        # Type loosening
        if ($line -match $typeLoosenRegex) {
            # Avoid double-counting with suppress
            if ($line -notmatch $suppressRegex -or $matches[0] -match 'as\s+any') {
                $debts += @{
                    file    = $file.FullName
                    line    = $lineNum
                    type    = 'type-loosen'
                    text    = $line.Trim()
                    ageDays = $ageDays
                    severity = if ($line -match 'as\s+any') { 'medium' } else { 'low' }
                }
                $counts['typeLoosen']++
            }
        }
    }
}

$result = @{
    debts  = $debts
    counts = $counts
}

# JSON output
$result | ConvertTo-Json -Depth 5

# Console summary
Write-Host "=== Tech Debt Scan Complete ==="
Write-Host "  Files scanned: $($files.Count)"
Write-Host "  Total debts:  $($debts.Count)"
Write-Host "  Suppress:     $($counts.suppress)"
Write-Host "  TODO/FIXME:   $($counts.todo)"
Write-Host "  Empty catch:  $($counts.emptyCatch)"
Write-Host "  Workaround:   $($counts.workaround)"
Write-Host "  Legacy:       $($counts.legacy)"
Write-Host "  Type loosen:  $($counts.typeLoosen)"
