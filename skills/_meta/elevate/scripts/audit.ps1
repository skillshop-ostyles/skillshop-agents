[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# PROTECTION: never modify ~/.claude/.
function Normalize($p) {
    $base = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
    $expanded = if ($p.StartsWith('~')) { Join-Path $base $p.Substring(1) } else { $p }
    return [System.IO.Path]::GetFullPath($expanded).TrimEnd('\')
}
$claudeRoot = Normalize (Join-Path $env:USERPROFILE '.claude')
$targetPath = Normalize $ProjectDir
# StartsWith case-insensitiv (OrdinalIgnoreCase): NTFS ist case-insensitiv, sonst
# would bypass the guard (review finding A2). -eq ist in
# PowerShell bereits case-insensitiv.
if ($targetPath -eq $claudeRoot -or $targetPath.StartsWith("$claudeRoot\", [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Error "PROTECTION: ProjectDir is inside $claudeRoot. Aborting."
    exit 1
}

if (-not (Test-Path -LiteralPath $ProjectDir)) {
    Write-Error "ProjectDir does not exist: $ProjectDir"
    exit 1
}

# Stack-Erkennung
$stack = 'generic'
if (Test-Path (Join-Path $ProjectDir 'package.json')) { $stack = 'node-ts' }
elseif (Test-Path (Join-Path $ProjectDir 'pyproject.toml')) { $stack = 'python' }
elseif (Test-Path (Join-Path $ProjectDir 'Cargo.toml')) { $stack = 'rust' }
elseif (Test-Path (Join-Path $ProjectDir 'go.mod')) { $stack = 'go' }

function Exist($rel) { Test-Path -LiteralPath (Join-Path $ProjectDir $rel) }

# a) Tests + Coverage
$testDir = (Exist 'tests') -or (Exist 'test') -or (Exist 'src/test') -or (Exist '__tests__')
$testCfg = (Exist 'vitest.config.*') -or (Exist 'jest.config.*') -or (Exist 'pytest.ini') -or (Exist 'pyproject.toml') -or (Exist 'Cargo.toml') -or (Exist 'go.mod')
$coverage = $testCfg -and (Select-String -Path (Join-Path $ProjectDir '*') -Pattern 'coverage' -List -Quiet -ErrorAction SilentlyContinue)
$a = if ($testDir -and $testCfg) { if ($coverage) { 'ok' } else { 'partial' } } else { 'missing' }

# b) Lint / Format
$lint = (Exist '.eslintrc*') -or (Exist 'eslint.config.*') -or (Exist '.prettierrc*') -or (Exist 'pyproject.toml') -or (Exist '.ruff.toml') -or (Exist 'rustfmt.toml') -or (Exist '.golangci.yml')
$b = if ($lint) { 'ok' } else { 'missing' }

# c) CI/CD
$ci = (Exist '.github/workflows') -or (Exist '.gitlab-ci.yml') -or (Exist 'azure-pipelines.yml') -or (Exist '.circleci')
$c = if ($ci) { 'ok' } else { 'missing' }

# d) Secrets-Management
$gitignore = Exist '.gitignore'
$envIgnored = $false
if ($gitignore) {
    $gi = Get-Content (Join-Path $ProjectDir '.gitignore') -ErrorAction SilentlyContinue
    $envIgnored = ($gi | Where-Object { $_ -match '\.env' }).Count -gt 0
}
$d = if ($envIgnored) { 'ok' } elseif ($gitignore) { 'partial' } else { 'missing' }

# e) Docs
$docs = (Exist 'README.md') -and ((Exist 'CONTRIBUTING.md') -or (Exist 'docs'))
$e = if ((Exist 'README.md') -and (Exist 'CONTRIBUTING.md')) { 'ok' } elseif (Exist 'README.md') { 'partial' } else { 'missing' }

# f) Type-Safety / Strict
$f = 'missing'
if ($stack -eq 'node-ts') {
    $pkg = Get-Content (Join-Path $ProjectDir 'package.json') -Raw -ErrorAction SilentlyContinue
    if ($pkg -match '"strict"\s*:\s*true') { $f = 'ok' } elseif ($pkg -match 'tsconfig') { $f = 'partial' }
} elseif ($stack -eq 'python') {
    $f = if (Select-String -Path (Join-Path $ProjectDir 'pyproject.toml') -Pattern 'strict|mypy' -Quiet -ErrorAction SilentlyContinue) { 'ok' } else { 'partial' }
} elseif ($stack -eq 'rust') { $f = 'partial' }
elseif ($stack -eq 'go') { $f = 'partial' }

# g) Dependency-Audit
$lock = (Exist 'package-lock.json') -or (Exist 'yarn.lock') -or (Exist 'pnpm-lock.yaml') -or (Exist 'Pipfile.lock') -or (Exist 'poetry.lock') -or (Exist 'Cargo.lock') -or (Exist 'go.sum')
$g = if ($lock) { 'ok' } else { 'missing' }

$audit = [ordered]@{
    stack = $stack
    dimensions = [ordered]@{
        a = [ordered]@{ name = 'Tests + Coverage'; status = $a }
        b = [ordered]@{ name = 'Lint / Format'; status = $b }
        c = [ordered]@{ name = 'CI/CD'; status = $c }
        d = [ordered]@{ name = 'Secrets-Management'; status = $d }
        e = [ordered]@{ name = 'Docs (README/CONTRIBUTING/ADR)'; status = $e }
        f = [ordered]@{ name = 'Type-Safety / Strict'; status = $f }
        g = [ordered]@{ name = 'Dependency-Audit'; status = $g }
    }
}

Write-Output (ConvertTo-Json $audit -Depth 5)

# Konsolen-Zusammenfassung
Write-Output "`n=== AUDIT: $stack ==="
foreach ($k in $audit.dimensions.Keys) {
    $dim = $audit.dimensions[$k]
    Write-Output "  [$k] $($dim.name): $($dim.status)"
}
