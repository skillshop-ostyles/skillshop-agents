[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir does not exist: $ProjectDir"
    exit 1
}

$root = (Resolve-Path -LiteralPath $ProjectDir).Path
function Exist($rel) { Test-Path -LiteralPath (Join-Path $root $rel) }

# -- 1. Stack-Erkennung (Muster elevate/scripts/audit.ps1) --
$stack = 'generic'
if (Exist 'package.json') { $stack = 'node-ts' }
elseif (Exist 'pyproject.toml') { $stack = 'python' }
elseif (Exist 'requirements.txt') { $stack = 'python' }
elseif (Exist 'Cargo.toml') { $stack = 'rust' }
elseif (Exist 'go.mod') { $stack = 'go' }
elseif (@(Get-ChildItem -LiteralPath $root -Filter '*.csproj' -ErrorAction SilentlyContinue).Count -gt 0) { $stack = 'dotnet' }

function Get-RuntimeVersion($cmd, $cmdArgs) {
    $c = Get-Command $cmd -ErrorAction SilentlyContinue
    if (-not $c) { return $null }
    try {
        $out = & $cmd $cmdArgs 2>$null
        if ($LASTEXITCODE -eq 0 -and $out) { return ([string]($out | Select-Object -First 1)).Trim() }
        return $null
    } catch {
        return $null
    }
}

$runtimes = [ordered]@{}
switch ($stack) {
    'node-ts' { $runtimes['node'] = Get-RuntimeVersion 'node' '-version' }
    'python' { $runtimes['python'] = Get-RuntimeVersion 'python' '-version' }
    'dotnet' { $runtimes['dotnet'] = Get-RuntimeVersion 'dotnet' '-version' }
    'go' { $runtimes['go'] = Get-RuntimeVersion 'go' 'version' }
}

# -- 2. Project metadata: test runner + test command --
$testRunner = $null
$testCommand = $null
if ($stack -eq 'node-ts' -and (Exist 'package.json')) {
    $pkg = Get-Content -LiteralPath (Join-Path $root 'package.json') -Raw | ConvertFrom-Json
    if ($pkg.scripts -and $pkg.scripts.test) { $testCommand = 'npm test' }
    $allDeps = @()
    if ($pkg.dependencies) { $allDeps += $pkg.dependencies.PSObject.Properties.Name }
    if ($pkg.devDependencies) { $allDeps += $pkg.devDependencies.PSObject.Properties.Name }
    if ($allDeps -contains 'vitest') { $testRunner = 'vitest' }
    elseif ($allDeps -contains 'jest') { $testRunner = 'jest' }
    elseif ($allDeps -contains 'mocha') { $testRunner = 'mocha' }
} elseif ($stack -eq 'python') {
    $candidateFiles = @('pyproject.toml', 'requirements.txt', 'requirements-dev.txt') | Where-Object { Exist $_ }
    foreach ($f in $candidateFiles) {
        if (Select-String -LiteralPath (Join-Path $root $f) -Pattern 'pytest' -Quiet -ErrorAction SilentlyContinue) {
            $testRunner = 'pytest'; $testCommand = 'pytest'; break
        }
    }
}

# -- 3. Git-Zustand --
$gitInfo = $null
$isRepo = & git -C $root rev-parse --is-inside-work-tree 2>$null
if ($LASTEXITCODE -eq 0 -and $isRepo -eq 'true') {
    $branch = [string](& git -C $root rev-parse -abbrev-ref HEAD 2>$null | Select-Object -First 1)
    $head = [string](& git -C $root rev-parse HEAD 2>$null | Select-Object -First 1)
    $statusOut = & git -C $root status -porcelain 2>$null
    $gitInfo = [ordered]@{ branch = $branch; head = $head; dirty = [bool]$statusOut }
}

# -- 4. Entry points (orientation, no claim to completeness) --
$entryNames = @('main', 'index', 'app', 'program')
$searchDirs = @($root)
if (Exist 'src') { $searchDirs += (Join-Path $root 'src') }

$entryPoints = @(
    foreach ($dir in $searchDirs) {
        Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue |
            Where-Object { $entryNames -contains [System.IO.Path]::GetFileNameWithoutExtension($_.Name).ToLower() } |
            ForEach-Object { $_.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/') }
    }
)

$result = [ordered]@{
    stack       = $stack
    runtimes    = $runtimes
    testRunner  = $testRunner
    testCommand = $testCommand
    git         = $gitInfo
    entryPoints = $entryPoints
}

Write-Output (ConvertTo-Json $result -Depth 6)

Write-Output "`n=== ENV-SNAPSHOT ==="
Write-Output "  Stack: $stack"
foreach ($k in $runtimes.Keys) { Write-Output "  Runtime $k`: $(if ($runtimes[$k]) { $runtimes[$k] } else { 'not found' })" }
Write-Output "  Test-Runner: $(if ($testRunner) { $testRunner } else { 'unknown' })"
if ($gitInfo) {
    $shortHead = if ($gitInfo.head) { $gitInfo.head.Substring(0, [Math]::Min(7, $gitInfo.head.Length)) } else { '?' }
    Write-Output "  Git: $($gitInfo.branch)@$shortHead dirty=$($gitInfo.dirty)"
} else {
    Write-Output '  Git: no repo'
}
Write-Output "  Entry-Points: $(if ($entryPoints.Count -gt 0) { $entryPoints -join ', ' } else { 'none found' })"
