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

$findings = New-Object System.Collections.Generic.List[object]
$counts = @{ pipelines = 0; jobs = 0; totalSteps = 0; hasCache = 0; hasMatrix = 0 }

# Find CI config files
$ciFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { -not (Test-ExcludedPath $_.FullName) } |
    Where-Object {
        $name = $_.Name.ToLower()
        $dir = $_.DirectoryName.ToLower()
        $name -eq '.github/workflows/ci.yml' -or $name -eq '.github/workflows/main.yml' -or
        $name -eq '.gitlab-ci.yml' -or $name -eq 'jenkinsfile' -or $name -eq '.circleci/config.yml' -or
        ($dir -match '\.github\\workflows' -and $name -match '\.ya?ml$')
    }

foreach ($f in $ciFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    $content = $lines -join "`n"

    $counts.pipelines++

    # Detect CI platform
    $platform = if ($relPath -match '\.gitlab-ci\.yml') { 'gitlab-ci' }
    elseif ($relPath -match 'circleci') { 'circleci' }
    elseif ($relPath -match 'Jenkinsfile') { 'jenkins' }
    else { 'github-actions' }

    $jobs = New-Object System.Collections.Generic.List[object]

    # Extract job names (GitHub Actions)
    $jobMatches = [regex]::Matches($content, '^\s+(\w[\w_-]*):\s*$', [System.Text.RegularExpressions.RegexOptions]::Multiline)
    # Alternative: find job: blocks
    $jobBlocks = [regex]::Matches($content, '(\w[\w_-]*):\s*\n\s+(runs-on|docker|image|steps)')

    foreach ($m in $jobBlocks) {
        $jobName = $m.Groups[1].Value
        $jobBlock = $m.Value

        $runsOn = if ($jobBlock -match 'runs-on:\s*(\S+)') { $matches[1] } else { 'unknown' }
        $hasMatrix = $content -match [regex]::Escape($jobName) -and $content -match 'matrix\s*:'
        $hasCache = $content -match [regex]::Escape($jobName) -and $content -match 'cache:|actions/cache|actions/upload-artifact'
        $stepCount = 0

        # Count steps in job
        $inJob = $false
        $depth = 0
        foreach ($line in $lines) {
            if ($line -match "^\s+$([System.Text.RegularExpressions.Regex]::Escape($jobName)):") { $inJob = $true }
            elseif ($inJob -and $line -match '^\s+\w+:' -and -not $line -match '^\s+steps:') { $inJob = $false }
            if ($inJob -and $line -match '^\s+-\s+(name:|run:|uses:)') { $stepCount++ }
        }

        $counts.jobs++
        if ($hasCache) { $counts.hasCache++ }
        if ($hasMatrix) { $counts.hasMatrix++ }
        $counts.totalSteps += $stepCount

        $jobs.Add([ordered]@{
                name      = $jobName
                runsOn    = $runsOn
                stepCount = $stepCount
                hasMatrix = $hasCache -or $hasMatrix  # track if cache or matrix present
                needs     = @()
            })
    }

    $findings.Add([ordered]@{
            file     = $relPath
            platform = $platform
            jobs     = $jobs.ToArray()
        })
}

$result = [ordered]@{
    pipelines = $findings.ToArray()
    counts    = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== CI-SCAN ==="
Write-Output "  Pipelines found: $($counts.pipelines)"
Write-Output "  Jobs: $($counts.jobs)"
Write-Output "  Total steps: $($counts.totalSteps)"
Write-Output "  Jobs with cache: $($counts.hasCache)"
