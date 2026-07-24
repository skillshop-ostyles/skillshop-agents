[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage')
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir does not exist: $ProjectDir"
    exit 1
}

$root = (Resolve-Path -LiteralPath $ProjectDir).Path
$excludeSet = @($Exclude | ForEach-Object { $_.ToLower() })

function Test-ExcludedPath($fullPath) {
    $rel = $fullPath.Substring($root.Length).TrimStart('\', '/')
    foreach ($part in ($rel -split '[\\/]')) {
        if ($excludeSet -contains $part.ToLower()) { return $true }
    }
    return $false
}

$runbooks = New-Object System.Collections.Generic.List[object]
$counts = @{ total = 0; claims = 0; valid = 0; stale = 0; invalid = 0 }

# Find runbook files
$runbookFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { -not (Test-ExcludedPath $_.FullName) } |
    Where-Object {
        $name = $_.Name.ToLower()
        ($name -match '^(runbook|playbook|on.?call|sop|ops.?guide|incident)') -or
        ($name -match '^\d{4}-\d{2}-\d{2}') -or
        ($name -eq 'readme.md' -and $_.DirectoryName -match 'deploy|ops|runbook')
    }

foreach ($f in $runbookFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }
    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue

    $assertions = New-Object System.Collections.Generic.List[object]

    # Extract command assertions
    foreach ($line in $lines) {
        if ($line -match '\$|>|#\s*(kubectl|docker|npm|git|ssh|curl|http|systemctl|service|journalctl)') {
            $cmd = $line.Trim()
            $claimsTotal++

            # Check if referenced resources exist
            $isValid = $true
            if ($cmd -match '(?i)kubectl\s+(get|describe|logs|exec)\s+(\S+)') {
                $resourceRef = $matches[2]
                # Check if referenced in any YAML file
                $found = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Extension -match '\.ya?ml' } |
                    Where-Object { (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match $resourceRef }
                if (-not $found) { $isValid = $false }
            }
            if ($cmd -match '(?i)docker\s+(compose|ps|logs|exec)\s+(\S+)') {
                $svcRef = $matches[2]
                $found = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -like 'docker-compose*' } |
                    Where-Object { (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match $svcRef }
                if (-not $found) { $isValid = $false }
            }

            if ($isValid) { $counts.valid++ } else { $counts.invalid++ }
            $assertions.Add([ordered]@{
                    kind    = 'command'
                    value   = $cmd
                    isValid = $isValid
                })
        }
    }

    # Extract dashboard/endpoint references
    if ($content -match '(?i)(grafana|datadog|prometheus|kibana|cloudwatch)\S*\.(com|net|io|app)\S+') {
        $assertions.Add([ordered]@{
                kind    = 'dashboard'
                value   = $matches[0]
                isValid = $true
            })
        $counts.valid++
    }

    $counts.total++
    $runbooks.Add([ordered]@{
            file       = $relPath
            assertions = $assertions.ToArray()
            lineCount  = $lines.Count
        })
}

if ($runbooks.Count -eq 0) {
    Write-Output (ConvertTo-Json ([ordered]@{ runbooks = @(); counts = @{ total = 0; claims = 0; valid = 0; stale = 0; invalid = 0 } }) -Depth 6)
    Write-Output "`n=== RUNBOOK-READ ==="
    Write-Output "  No runbook files found"
    exit 0
}

$result = [ordered]@{
    runbooks = $runbooks.ToArray()
    counts   = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== RUNBOOK-READ ==="
Write-Output "  Runbook files: $($counts.total)"
Write-Output "  Claims: $($counts.valid + $counts.invalid) (valid=$($counts.valid) invalid=$($counts.invalid))"
