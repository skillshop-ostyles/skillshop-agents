[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectDir,

    [Parameter(Mandatory = $true)]
    [string]$AnswersFile
)

$ErrorActionPreference = 'Stop'

# SCHUTZ: ~/.claude/ niemals veraendern. Pfad ohne Erstellung normalisieren
# (GetFullPath macht keinen Zugriff aufs Dateisystem, erstellt nichts).
function Normalize($p) {
    $base = if ($env:USERPROFILE) { $env:USERPROFILE } else { $HOME }
    $expanded = if ($p.StartsWith('~')) { Join-Path $base $p.Substring(1) } else { $p }
    return [System.IO.Path]::GetFullPath($expanded).TrimEnd('\')
}

$claudeRoot = Normalize (Join-Path $env:USERPROFILE '.claude')
$targetPath = Normalize $ProjectDir

if ($targetPath -eq $claudeRoot -or $targetPath.StartsWith("$claudeRoot\")) {
    Write-Error "SCHUTZ: ProjectDir liegt unter $claudeRoot. Das Verzeichnis C:\Users\ostol\.claude\ darf NIEMALS veraendert werden. Abbruch."
    exit 1
}

if (-not (Test-Path -LiteralPath $AnswersFile)) {
    Write-Error "AnswersFile nicht gefunden: $AnswersFile"
    exit 1
}

$answers = Get-Content -LiteralPath $AnswersFile -Raw -Encoding UTF8 | ConvertFrom-Json

$name = if ($answers.name) { $answers.name } else { (Split-Path $ProjectDir -Leaf) }
$goal = if ($answers.goal) { $answers.goal } else { '(nicht definiert)' }
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
# Projekt-Bibel — nicht verhandelbar

Die verbindlichen Regeln für dieses Projekt sind in der globalen Benutzer-Bibel festgelegt:

- **Quelle:** `C:\Users\ostol\.claude\CLAUDE.md` (gültig für ALLE Projekte dieses Users)
- **Status:** IMMER präsent, aktiv und gültig. Nicht verhandelbar.

## Projekt-Kurzprofil
- **Name:** $name
- **Ziel:** $goal
- **Stack:** $stack ($pkgManager)
- **Plattform:** $(($platform -join ', '))
- **Blocker:** $blockers

## Verankerung
Diese Datei ist die projekt-lokale Instanz der Bibel. Bei Widersprüchen zwischen
projektspezifischem Code/Text und der Bibel gilt die Bibel.
"@
Write-File 'CLAUDE.md' $bibleRef

$manifest = @"
# Manifest — $name

## Ziel
$goal

## Scope
- Stack: $stack ($pkgManager)
- Plattform: $(($platform -join ', '))
- Tooling: $(($tooling -join ', '))

## Secrets / Tokens
$(if ($secrets.Count -eq 0) { 'none' } else { ($secrets | ForEach-Object { "- $_" }) -join "`n" })

## Blocker
$blockers

## Erstellt
$(Get-Date -Format 'yyyy-MM-dd HH:mm')
"@
Write-File 'ops/manifest.md' $manifest

$tracking = @"
# Tracking — $name

## Status
- Phase: Init
- Letzte Aktivität: $(Get-Date -Format 'yyyy-MM-dd HH:mm')

## Offen
- (eintragen)

## Blocker
$blockers

## Sprint-Referenz
- Siehe ops/sprints/
"@
Write-File 'ops/tracking.md' $tracking

$sprintsReadme = @"
# Sprints — $name

Jeder Sprint ist eine Datei `sprint-NN.md` in diesem Ordner.

Template:
- Ziel
- Tasks
- Done / Offen
- Blockierungen
"@
Write-File 'ops/sprints/README.md' $sprintsReadme

$readme = @"
# $name

> $goal

Siehe `ops/manifest.md` für Ziel & Scope und `ops/tracking.md` für Status.
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
        Write-File 'src/index.ts' "export function main(): void {`n  // TODO: Einstiegspunkt`n}`n"
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
        Write-File 'src/main.txt' "# Einstiegspunkt-Stub für Stack: $stack`n"
    }
}

Write-Output "Projekt '$name' initialisiert in $ProjectDir"
Write-Output "  Struktur erstellt: $(($layoutDirs -join '/')) + ops/ + README.md + .gitignore + CLAUDE.md"
Write-Output "  Naechster Schritt: 'weiter' eingeben fuer Session-Start-Routine."
