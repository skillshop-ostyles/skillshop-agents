[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,
    [int]$GitRange = 20
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir does not exist: $ProjectDir"
    exit 1
}

$root = (Resolve-Path -LiteralPath $ProjectDir).Path

# Find prompt files by convention
$promptPatterns = @('prompts', 'system-prompts', 'prompt-templates', 'instructions')
$promptFiles = New-Object System.Collections.Generic.List[string]

foreach ($pattern in $promptPatterns) {
    $dir = Join-Path -Path $root -ChildPath $pattern
    if (Test-Path -LiteralPath $dir) {
        Get-ChildItem -LiteralPath $dir -Recurse -File | ForEach-Object {
            [void]$promptFiles.Add($_.FullName)
        }
    }
}

# Also find files named *_prompt* or *prompt* with txt/md extensions
Get-ChildItem -LiteralPath $root -Recurse -File -Include @('*prompt*.txt', '*prompt*.md', '*prompt*.py', '*prompt*.ts', '*prompt*.js') -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch 'node_modules|\.git|dist' } |
    ForEach-Object {
        if ($promptFiles -notcontains $_.FullName) { [void]$promptFiles.Add($_.FullName) }
    }

$drifts = New-Object System.Collections.Generic.List[object]

# Check git history for each prompt file
$originalLocation = Get-Location
try {
    Set-Location -LiteralPath $root -ErrorAction SilentlyContinue
    $null = git rev-parse --is-inside-work-tree 2>$null
    if ($LASTEXITCODE -ne 0) {
        # No git repo - report what we found
        $result = [ordered]@{
            drifts = @()
            promptFiles = $promptFiles.ToArray()
            counts = @{ total = 0; benign = 0; monitor = 0; significant = 0; critical = 0 }
            gitAvailable = $false
        }
        Write-Output (ConvertTo-Json $result -Depth 6)
        Write-Output "`n=== PROMPT-DRIFT ==="
        Write-Output "  Git not available. Found $($promptFiles.Count) prompt files."
        return
    }

    foreach ($f in $promptFiles) {
        $relPath = $f.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
        $logOutput = git log --oneline -$GitRange -- $relPath 2>$null
        if (-not $logOutput) { continue }

        $commits = $logOutput -split "`n" | Where-Object { $_ -ne '' }
        for ($ci = 0; $ci -lt $commits.Count; $ci++) {
            $commitLine = $commits[$ci]
            $commitHash = ($commitLine -split '\s')[0]
            $commitMsg = $commitLine.Substring($commitHash.Length).Trim()

            # Skip first commit (no parent to diff against)
            if ($ci -eq $commits.Count - 1) { continue }
            $diffOutput = git diff "$($commitHash)~1..$commitHash" -- $relPath 2>$null
            if (-not $diffOutput) { continue }

            # Analyze diff for type of change
            $hasFormatChange = $diffOutput -match '(?i)(format|json|xml|yaml|csv|markdown|output structure|schema)'
            $hasSafetyChange = $diffOutput -match '(?i)(safety|harmful|dangerous|injection|guardrail|boundary|restricted|forbidden)'
            $hasExampleChange = $diffOutput -match '(?i)(example|sample|for instance|e\.g\.|i\.e\.|demonstrat)'

            # Extract added/removed lines for summary
            $addedLines = @($diffOutput -split "`n" | Where-Object { $_ -match '^\+[^+]' -and $_ -notmatch '^\+\+\+' })
            $removedLines = @($diffOutput -split "`n" | Where-Object { $_ -match '^-[^-]' -and $_ -notmatch '^---' })

            # Estimate severity
            $hasOutputConstraintRemoved = $false
            $hasSafetyWeakened = $false
            foreach ($line in $removedLines) {
                if ($line -match '(?i)(respond in|output format|must return|only respond with)') { $hasOutputConstraintRemoved = $true }
                if ($line -match '(?i)(never|always|must not|do not|forbidden|prohibited|reject)') { $hasSafetyWeakened = $true }
            }

            if ($hasOutputConstraintRemoved -or $hasSafetyWeakened) {
                $severity = 'critical'
            } elseif ($hasFormatChange -or $hasSafetyChange -or $hasExampleChange) {
                $severity = 'significant'
            } elseif (($addedLines.Count + $removedLines.Count) -gt 10) {
                $severity = 'monitor'
            } else {
                $severity = 'benign'
            }

            $drifts.Add([ordered]@{
                    file = $relPath
                    commit = $commitHash
                    message = $commitMsg
                    changedSections = @('prompt content')
                    hasFormatChange = ($hasFormatChange -or $hasOutputConstraintRemoved)
                    hasSafetyChange = ($hasSafetyChange -or $hasSafetyWeakened)
                    hasExampleChange = $hasExampleChange
                    addedLines = $addedLines.Count
                    removedLines = $removedLines.Count
                    severity = $severity
                })
        }
    }
}
finally {
    Set-Location -LiteralPath $originalLocation
}

$counts = @{ total = $drifts.Count; benign = 0; monitor = 0; significant = 0; critical = 0 }
foreach ($d in $drifts) {
    if ($counts.ContainsKey($d.severity)) { $counts[$d.severity]++ }
}

$result = [ordered]@{
    drifts = $drifts.ToArray()
    promptFiles = $promptFiles.ToArray()
    counts = $counts
    gitAvailable = $true
}

Write-Output (ConvertTo-Json $result -Depth 6)
Write-Output "`n=== PROMPT-DRIFT ==="
Write-Output "  Prompt files found: $($promptFiles.Count)"
foreach ($key in ($counts.Keys | Where-Object { $_ -ne 'total' })) {
    Write-Output "  $key`: $($counts[$key])"
}
