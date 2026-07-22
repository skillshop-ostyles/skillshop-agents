[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [Parameter(Mandatory = $true)]
    [string]$ConfigFile
)

$ErrorActionPreference = 'Stop'

# SCHUTZ: ~/.claude/ niemals veraendern.
function Normalize($p) {
    $base = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
    $expanded = if ($p.StartsWith('~')) { Join-Path $base $p.Substring(1) } else { $p }
    return [System.IO.Path]::GetFullPath($expanded).TrimEnd('\')
}
$claudeRoot = Normalize (Join-Path $env:USERPROFILE '.claude')
$targetPath = Normalize $ProjectDir
# StartsWith case-insensitiv (OrdinalIgnoreCase): NTFS ist case-insensitiv, sonst
# wuerde C:\USERS\...\.claude den Guard umgehen (Review-Befund A2). -eq ist in
# PowerShell bereits case-insensitiv.
if ($targetPath -eq $claudeRoot -or $targetPath.StartsWith("$claudeRoot\", [System.StringComparison]::OrdinalIgnoreCase)) {
    Write-Error "SCHUTZ: ProjectDir liegt unter $claudeRoot. Abbruch."
    exit 1
}

if (-not (Test-Path -LiteralPath $ConfigFile)) {
    Write-Error "ConfigFile nicht gefunden: $ConfigFile"
    exit 1
}

$cfg = Get-Content -LiteralPath $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json
$stack = if ($cfg.stack) { $cfg.stack } else { 'generic' }
$ci = if ($cfg.ci) { $cfg.ci } else { 'github-actions' }
$approve = $cfg.approve

function Write-File($rel, $content) {
    $full = Join-Path $ProjectDir $rel
    New-Item -ItemType Directory -Force -Path (Split-Path $full) | Out-Null
    Set-Content -LiteralPath $full -Value $content -Encoding UTF8 -NoNewline
}

$templateDir = Join-Path $PSScriptRoot 'templates'

# a) Tests + Coverage
if ($approve.a) {
    switch ($stack) {
        'node-ts' {
            Write-File 'vitest.config.ts' "import { defineConfig } from 'vitest/config'`nexport default defineConfig({ test: { coverage: { provider: 'v8', reporter: ['text','html'] } } })`n"
            Write-File 'tests/smoke.test.ts' "import { describe, it, expect } from 'vitest'`ndescribe('smoke', () => { it('works', () => { expect(1+1).toBe(2) }) })`n"
        }
        'python' {
            Write-File 'tests/test_smoke.py' "def test_smoke():`n    assert 1 + 1 == 2`n"
            Write-File 'pytest.ini' "[pytest]`naddopts = --cov=src --cov-report=term-missing`n"
        }
        'rust' {
            Write-File 'tests/smoke.rs' "#[test]`nfn smoke() { assert_eq!(1 + 1, 2); }`n"
        }
        'go' {
            Write-File 'smoke_test.go' "package main`n`nimport \"testing\"`n`nfunc TestSmoke(t *testing.T) { if 1+1 != 2 { t.Fail() } }`n"
        }
        default {
            Write-File 'tests/README.md' "# Tests`nFuege hier Stack-spezifische Tests hinzu.`n"
        }
    }
    Write-Output "[a] Tests + Coverage angelegt ($stack)"
}

# b) Lint / Format
if ($approve.b) {
    switch ($stack) {
        'node-ts' {
            Write-File '.eslintrc.json' '{ "root": true, "extends": ["eslint:recommended", "typescript-eslint/recommended"], "parser": "@typescript-eslint/parser" }'
            Write-File '.prettierrc' '{ "semi": true, "singleQuote": true }'
        }
        'python' {
            Write-File '.ruff.toml' "line-length = 100`ntarget-version = \"py311\"`n"
        }
        'rust' {
            Write-File 'rustfmt.toml' "max_width = 100`n"
        }
        'go' {
            Write-File '.golangci.yml' "run:`n  timeout: 5m`nlinters:`n  enable: [govet, errcheck, staticcheck]`n"
        }
        default {
            Write-File '.editorconfig' "root = true`n[*]`ncharset = utf-8`nindent_style = space`n"
        }
    }
    Write-Output "[b] Lint / Format angelegt ($stack)"
}

# c) CI/CD — nur gewaehltes System
if ($approve.c) {
    $ciSrc = Join-Path $templateDir "ci-$ci.yml"
    if (Test-Path $ciSrc) {
        switch ($ci) {
            'github-actions' { Write-File '.github/workflows/ci.yml' (Get-Content $ciSrc -Raw) }
            'gitlab' { Write-File '.gitlab-ci.yml' (Get-Content $ciSrc -Raw) }
            'azure' { Write-File 'azure-pipelines.yml' (Get-Content $ciSrc -Raw) }
            'local' { Write-File 'scripts/ci-local.ps1' (Get-Content $ciSrc -Raw) }
        }
        Write-Output "[c] CI angelegt: $ci"
    } else {
        Write-Output "[c] CI-Vorlage fehlt fuer: $ci (uebersprungen)"
    }
}

# d) Secrets-Management
if ($approve.d) {
    $giPath = Join-Path $ProjectDir '.gitignore'
    $gi = if (Test-Path $giPath) { Get-Content $giPath } else { @() }
    if (($gi | Where-Object { $_ -match '\.env' }).Count -eq 0) {
        $gi += '', '# secrets', '.env', '.env.*', '*.secret'
        Set-Content -LiteralPath $giPath -Value ($gi -join "`n") -Encoding UTF8
    }
    Write-Output "[d] Secrets-Hygiene (.gitignore) geprueft/ergaenzt"
}

# e) Docs
if ($approve.e) {
    if (-not (Test-Path (Join-Path $ProjectDir 'README.md'))) {
        Write-File 'README.md' "# $stack Projekt`n`nSiehe ops/manifest.md für Kontext.`n"
    }
    Write-File 'CONTRIBUTING.md' "# Contributing`n`n## Setup`n1. Abhaengigkeiten installieren`n2. `scripts/ci-local.ps1` lokal ausfuehren`n`n## Regeln`n- Tests + Lint vor jedem PR`n- Siegel: alle CI-Checks gruen`n"
    New-Item -ItemType Directory -Force -Path (Join-Path $ProjectDir 'docs/adr') | Out-Null
    Write-File 'docs/adr/0001-record-architecture-decisions.md' "# 1. Record Architecture Decisions`n`nDatum: $(Get-Date -Format 'yyyy-MM-dd')`n`n## Status`nAngenommen`n`n## Kontext`n<Worum geht es?>`n`n## Entscheidung`n<Was wurde entschieden?>`n`n## Konsequenzen`n<Was folgt daraus?>`n"
    Write-Output "[e] Docs (CONTRIBUTING + ADR) angelegt"
}

# f) Type-Safety / Strict
if ($approve.f) {
    switch ($stack) {
        'node-ts' {
            $tsPath = Join-Path $ProjectDir 'tsconfig.json'
            if (Test-Path $tsPath) {
                $ts = Get-Content $tsPath -Raw
                if ($ts -notmatch '"strict"') {
                    $ts = $ts -replace '(\{\s*"compilerOptions"\s*:\s*\{)', "`$1`n  `"strict`": true,"
                    Set-Content -LiteralPath $tsPath -Value $ts -Encoding UTF8
                }
            } else {
                Write-File 'tsconfig.json' '{ "compilerOptions": { "strict": true, "target": "ES2022", "module": "ESNext" } }'
            }
        }
        'python' {
            Write-File 'pyproject.mypy.toml' "[mypy]`nstrict = true`n"
        }
        default {
            Write-Output "[f] ${stack}: keine automatische Strict-Config (manuell pruefen)"
        }
    }
    Write-Output "[f] Type-Safety / Strict angelegt ($stack)"
}

# g) Dependency-Audit
if ($approve.g) {
    switch ($stack) {
        'node-ts' { Write-File 'scripts/audit-deps.ps1' "npm audit --audit-level=high`n" }
        'python' { Write-File 'scripts/audit-deps.ps1' "pip-audit`n" }
        'rust' { Write-File 'scripts/audit-deps.ps1' "cargo audit`n" }
        'go' { Write-File 'scripts/audit-deps.ps1' "go list -m -u all`n" }
        default { Write-File 'scripts/audit-deps.ps1' "# Dependency-Audit: Stack-spezifisch ergaenzen`n" }
    }
    Write-Output "[g] Dependency-Audit-Skript angelegt ($stack)"
}

Write-Output "`nElevate abgeschlossen."
