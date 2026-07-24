[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [string[]]$Exclude = @('node_modules', 'dist', 'build', '.git', 'vendor', 'coverage', '.env.example')
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

function Parse-EnvFile($path) {
    $result = @{}
    $lines = Get-Content -LiteralPath $path -ErrorAction SilentlyContinue
    if (-not $lines) { return $result }
    foreach ($line in $lines) {
        $line = $line.Trim()
        if (-not $line -or $line.StartsWith('#')) { continue }
        $eqIdx = $line.IndexOf('=')
        if ($eqIdx -le 0) { continue }
        $key = $line.Substring(0, $eqIdx).Trim()
        $val = $line.Substring($eqIdx + 1).Trim()
        $result[$key] = $val
    }
    return $result
}

$envFiles = Get-ChildItem -LiteralPath $root -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { -not (Test-ExcludedPath $_.FullName) } |
    Where-Object {
        $name = $_.Name.ToLower()
        $name -match '^\.env' -or
        $name -match '\.env\.(development|staging|production|test|local|prod|dev)$'
    }

if ($envFiles.Count -eq 0) {
    Write-Output (ConvertTo-Json ([ordered]@{ envFiles = @(); drifts = @(); counts = @{ total = 0; drifts = 0; safe = 0; review = 0; critical = 0 } }) -Depth 6)
    Write-Output "`n=== ENV-DIFF ==="
    Write-Output "  No environment files found"
    exit 0
}

$envData = @{}
$envOrder = @()
foreach ($f in $envFiles) {
    $relPath = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
    $envName = switch -Wildcard ($f.Name.ToLower()) {
        '.env' { 'default' }
        '*.env.development' { 'development' }
        '*.env.staging' { 'staging' }
        '*.env.production' { 'production' }
        '*.env.test' { 'test' }
        '*.env.local' { 'local' }
        '*.env.prod' { 'production' }
        '*.env.dev' { 'development' }
        default { $f.Name.Replace('.env', '').Trim('.') }
    }
    $envData[$envName] = @{ file = $relPath; vars = Parse-EnvFile $f.FullName }
    $envOrder += $envName
}

# Collect all unique keys
$allKeys = @{}
foreach ($env in $envOrder) {
    foreach ($k in $envData[$env].vars.Keys) {
        $allKeys[$k] = $true
    }
}

$drifts = New-Object System.Collections.Generic.List[object]
$counts = @{ total = $allKeys.Count; drifts = 0; safe = 0; review = 0; critical = 0 }

foreach ($key in $allKeys.Keys) {
    $values = [ordered]@{}
    $missingEnvs = @()
    foreach ($env in $envOrder) {
        if ($envData[$env].vars.ContainsKey($key)) {
            $values[$env] = $envData[$env].vars[$key]
        }
        else {
            $values[$env] = $null
            $missingEnvs += $env
        }
    }

    $uniqueVals = $values.Values | Where-Object { $_ -ne $null } | Select-Object -Unique
    $consistent = $uniqueVals.Count -le 1

    if (-not $consistent -or $missingEnvs.Count -gt 0) {
        $counts.drifts++

        # Assess risk
        $isSecret = $key -match '(?i)(key|secret|password|token|credential|cert|private)'
        $isUrl = $key -match '(?i)(url|host|endpoint|connection|dsn)'

        $risk = 'safe'
        if ($isSecret -and (-not $consistent)) { $risk = 'critical' }
        elseif ($isSecret) { $risk = 'review' }
        elseif ($missingEnvs.Count -ge 2) { $risk = 'review' }
        elseif ($isUrl -and (-not $consistent)) { $risk = 'review' }

        switch ($risk) {
            'safe' { $counts.safe++ }
            'review' { $counts.review++ }
            'critical' { $counts.critical++ }
        }

        $drifts.Add([ordered]@{
                key          = $key
                values       = $values
                missingEnvs  = $missingEnvs
                isConsistent = $consistent
                risk         = $risk
            })
    }
}

$result = [ordered]@{
    envFiles = $envOrder | ForEach-Object { @{ name = $_; file = $envData[$_].file } }
    drifts   = $drifts.ToArray()
    counts   = $counts
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== ENV-DIFF ==="
Write-Output "  Env files found: $($envFiles.Count) ( $($envOrder -join ', ') )"
Write-Output "  Total keys: $($counts.total)"
Write-Output "  Drifts: $($counts.drifts) (safe=$($counts.safe) review=$($counts.review) critical=$($counts.critical))"
