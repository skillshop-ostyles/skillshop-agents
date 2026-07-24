[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [Parameter(Mandatory = $true)]
    [string]$AnswersFile
)

$ErrorActionPreference = 'Stop'

# PROTECTION: never modify ~/.claude/. Normalize path without creating anything
# (GetFullPath does not access the filesystem, creates nothing).
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
    Write-Error "PROTECTION: ProjectDir is inside $claudeRoot. This directory must NEVER be modified. Aborting."
    exit 1
}

if (-not (Test-Path -LiteralPath $AnswersFile)) {
    Write-Error "AnswersFile not found: $AnswersFile"
    exit 1
}

$answers = Get-Content -LiteralPath $AnswersFile -Raw -Encoding UTF8 | ConvertFrom-Json

$name = if ($answers.name) { $answers.name } else { (Split-Path $ProjectDir -Leaf) }
$goal = if ($answers.goal) { $answers.goal } else { '(not defined)' }
$stack = if ($answers.stack) { $answers.stack } else { 'generic' }
$pkgManager = if ($answers.pkgManager) { $answers.pkgManager } else { 'n/a' }
$layout = if ($answers.layout) { $answers.layout } else { 'src/docs/ops' }
$tooling = if ($answers.tooling) { $answers.tooling } else { @() }
$docs = if ($answers.docs) { $answers.docs } else { @('manifest', 'tracking', 'sprints') }
$secrets = if ($answers.secrets) { $answers.secrets } else { @() }
$platform = if ($answers.platform) { $answers.platform } else { @() }
$blockers = if ($answers.blockers) { $answers.blockers } else { 'none' }

$layoutDirs = $layout -split '/' | Where-Object { $_ -and $_ -ne 'ops' }
foreach ($d in $layoutDirs) {
    New-Item -ItemType Directory -Force -Path (Join-Path $ProjectDir $d) | Out-Null
}

$opsDir = Join-Path $ProjectDir 'ops'
New-Item -ItemType Directory -Force -Path $opsDir | Out-Null
$sprintsDir = Join-Path $opsDir 'sprints'
New-Item -ItemType Directory -Force -Path $sprintsDir | Out-Null
New-Item -ItemType File -Force -Path (Join-Path $sprintsDir '.gitkeep') | Out-Null

function Write-File($relPath, $content) {
    $full = Join-Path $ProjectDir $relPath
    New-Item -ItemType Directory -Force -Path (Split-Path $full) | Out-Null
    Set-Content -LiteralPath $full -Value $content -Encoding UTF8 -NoNewline
}

$bibleRef = @"
# Project Rules - non-negotiable

The binding rules for this project are defined in the user's global CLAUDE.md configuration.

## Project Profile
- **Name:** $name
- **Goal:** $goal
- **Stack:** $stack ($pkgManager)
- **Platform:** $(($platform -join ', '))
- **Blockers:** $blockers
"@
Write-File 'CLAUDE.md' $bibleRef

$manifest = @"
# Manifest - $name

## Goal
$goal

## Scope
- Stack: $stack ($pkgManager)
- Platform: $(($platform -join ', '))
- Tooling: $(($tooling -join ', '))

## Secrets / Tokens
$(if ($secrets.Count -eq 0) { 'none' } else { ($secrets | ForEach-Object { "- $_" }) -join "`n" })

## Blockers
$blockers

## Created
$(Get-Date -Format 'yyyy-MM-dd HH:mm')
"@
Write-File 'ops/manifest.md' $manifest

$tracking = @"
# Tracking - $name

## Status
- Phase: Init
- Last activity: $(Get-Date -Format 'yyyy-MM-dd HH:mm')

## Open
- (add items)

## Blockers
$blockers

## Sprint Reference
- See ops/sprints/
"@
Write-File 'ops/tracking.md' $tracking

$sprintsReadme = @"
# Sprints - $name

Each sprint is a file `sprint-NN.md` in this folder.

Template:
- Goal
- Tasks
- Done / Open
- Blockers
"@
Write-File 'ops/sprints/README.md' $sprintsReadme

$readme = @"
# $name

> $goal

Siehe `ops/manifest.md` fÃ¼r Ziel & Scope und `ops/tracking.md` fÃ¼r Status.
"@
Write-File 'README.md' $readme

$gitignoreLines = @(
    '# dependencies',
    'node_modules/',
    '.venv/',
    '__pycache__/',
    'target/',
    'bin/',
    '# build output',
    'dist/',
    'build/',
    'out/',
    '# secrets',
    '.env',
    '.env.*',
    '# misc',
    '.DS_Store',
    '*.log'
)
Write-File '.gitignore' ($gitignoreLines -join "`n")

switch ($stack) {
    'node-ts' {
        Write-File 'src/index.ts' "export function main(): void {`n  // TODO: entry point`n}`n"
    }
    'python' {
        Write-File 'src/main.py' "def main() -> None:`n    pass`n`n`nif __name__ == '__main__':`n    main()`n"
    }
    'go' {
        Write-File 'src/main.go' "package main`n`nfunc main() {`n`n}`n"
    }
    'rust' {
        Write-File 'src/main.rs' "fn main() {`n    // TODO`n}`n"
    }
    default {
        Write-File 'src/main.txt' "# Entry point stub for stack: $stack`n"
    }
}

Write-Output "Project '$name' initialized in $ProjectDir"
Write-Output "  Structure created: $(($layoutDirs -join '/')) + ops/ + README.md + .gitignore + project config"
Write-Output "  Next step: type 'weiter' for session start routine."
