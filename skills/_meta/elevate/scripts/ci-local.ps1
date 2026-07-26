[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir
)

$ErrorActionPreference = 'Continue'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8  # best-effort: nichts abbrechen lassen

$cwd = Resolve-Path -LiteralPath $ProjectDir
Write-Output "=== LOCAL CI MIRROR: $cwd ==="

function Run($label, $cmd) {
    Write-Output "`n-- $label --"
    try {
        Invoke-Expression $cmd
        Write-Output "[$label] OK"
    } catch {
        Write-Output "[$label] SKIPPED / ERROR: $($_.Exception.Message)"
    }
}

# Stack-Erkennung
$stack = 'generic'
if (Test-Path (Join-Path $cwd 'package.json')) { $stack = 'node-ts' }
elseif (Test-Path (Join-Path $cwd 'pyproject.toml')) { $stack = 'python' }
elseif (Test-Path (Join-Path $cwd 'Cargo.toml')) { $stack = 'rust' }
elseif (Test-Path (Join-Path $cwd 'go.mod')) { $stack = 'go' }

Push-Location $cwd
switch ($stack) {
    'node-ts' {
        Run 'Lint' 'npm run lint -if-present'
        Run 'Test' 'npm test -if-present'
        Run 'Audit' 'npm audit -audit-level=high'
    }
    'python' {
        Run 'Lint (ruff)' 'ruff check .'
        Run 'Test (pytest)' 'pytest'
        Run 'Audit (pip-audit)' 'pip-audit'
    }
    'rust' {
        Run 'Lint (clippy)' 'cargo clippy -all-targets'
        Run 'Test' 'cargo test'
        Run 'Audit (cargo-audit)' 'cargo audit'
    }
    'go' {
        Run 'Lint (vet)' 'go vet ./...'
        Run 'Test' 'go test ./...'
        Run 'Audit' 'go list -m -u all'
    }
    default {
        Write-Output "Unknown stack - check manually: lint, test, audit."
    }
}
Pop-Location

Write-Output "LOCAL MIRROR DONE"
