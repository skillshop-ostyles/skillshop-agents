[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,
    [string[]]$Extensions = @('py', 'ts', 'js', 'tsx', 'jsx', 'cs', 'go', 'rs', 'java', 'rb'),
    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage', '__pycache__', 'venv', '.venv')
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
$extSet = @($Extensions | ForEach-Object { $_.TrimStart('.').ToLower() })

function Test-Excluded($fullPath) {
    $rel = $fullPath.Substring($root.Length).TrimStart('\', '/')
    foreach ($part in ($rel -split '[\\/]')) {
        if ($excludeSet -contains $part.ToLower()) { return $true }
    }
    return $false
}

$issues = New-Object System.Collections.Generic.List[object]
$allFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $extSet -contains $_.Extension.TrimStart('.').ToLower() } |
    Where-Object { -not (Test-Excluded $_.FullName) }

foreach ($f in $allFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $lines = Get-Content -LiteralPath $f.FullName -ErrorAction SilentlyContinue
    if (-not $lines) { continue }
    $content = $lines -join "`n"

    # Check global seed settings
    $hasGlobalSeed = $content -match '(?i)(seed|random_state|deterministic)\s*[=:]\s*(\d+)'
    $cudaDeterministic = $content -match '(?i)(torch\.backends\.cudnn\.deterministic|cudnn\.benchmark|deterministic.*True)'
    $tfDeterministic = $content -match '(?i)(tf\.config\.experimental\.enable_op_determinism|tf\.deterministic|TF_DETERMINISTIC)'

    # Check per-file issues
    $fileIssues = New-Object System.Collections.Generic.List[object]

    # Missing seed
    if (-not $hasGlobalSeed) {
        if ($content -match '(?i)(np\.random|torch\.rand|tf\.random|random\.randint|random\.choice|random\.shuffle|shuffle=True|DataLoader|train_test_split)') {
            $fileIssues.Add([ordered]@{ type = 'missing-seed'; detail = 'random ops without global seed' })
        }
    }

    # GPU non-determinism
    if ($content -match '(?i)(\.cuda\(\)|\.to\(.*cuda|device.*cuda|CUDA_VISIBLE|torch\.cuda)') {
        if (-not $cudaDeterministic) {
            $fileIssues.Add([ordered]@{ type = 'gpu-nondeterminism'; detail = 'GPU ops without deterministic config' })
        }
    }

    # Shuffle without seed
    if ($content -match '(?i)shuffle\s*=\s*True' -and -not $hasGlobalSeed) {
        $fileIssues.Add([ordered]@{ type = 'shuffle-order'; detail = 'DataLoader shuffle without seed' })
    }

    # Parallel non-determinism
    if ($content -match '(?i)(num_workers|multiprocessing|ThreadPool|Parallel\(|\.parquet|dask)') {
        $fileIssues.Add([ordered]@{ type = 'parallel-nondeterminism'; detail = 'parallel processing without determinism guarantees' })
    }

    if ($fileIssues.Count -gt 0) {
        # Determine severity
        $severity = 'mostly-deterministic'
        if (-not $hasGlobalSeed -and $fileIssues.Count -ge 2) { $severity = 'non-deterministic' }
        if (-not $hasGlobalSeed -and $fileIssues.Count -ge 3) { $severity = 'chaotic' }
        if ($hasGlobalSeed -and $content -match '(?i)(\.cuda\b|train_test_split|DataLoader)' -and -not $cudaDeterministic) {
            $severity = 'mostly-deterministic'
        }

        $issues.Add([ordered]@{
                file = $relPath
                line = 1
                issues = $fileIssues.ToArray()
                hasGlobalSeed = $hasGlobalSeed
                hasGpuConfig = ($cudaDeterministic -or $tfDeterministic)
                issueCount = $fileIssues.Count
                severity = $severity
            })
    } elseif ($content -match '(?i)(np\.random|torch|tf\.|DataLoader|train_test_split|\.cuda\b)') {
        # File has ML ops but no determinism issues - good
        if ($hasGlobalSeed) {
            $issues.Add([ordered]@{
                    file = $relPath
                    line = 1
                    issues = @()
                    hasGlobalSeed = $true
                    hasGpuConfig = ($cudaDeterministic -or $tfDeterministic)
                    issueCount = 0
                    severity = 'deterministic'
                })
        }
    }
}

$counts = @{ total = $issues.Count; deterministic = 0; 'mostly-deterministic' = 0; 'non-deterministic' = 0; chaotic = 0 }
foreach ($i in $issues) {
    if ($counts.ContainsKey($i.severity)) { $counts[$i.severity]++ }
}

$result = [ordered]@{
    determinismIssues = $issues.ToArray()
    counts = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)
Write-Output "`n=== DETERMINISM-SCAN ==="
Write-Output "  Pipelines analyzed: $($issues.Count)"
foreach ($key in ($counts.Keys | Where-Object { $_ -ne 'total' })) {
    Write-Output "  $key`: $($counts[$key])"
}
