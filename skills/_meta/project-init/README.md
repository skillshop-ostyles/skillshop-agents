# project-init

✅ **Verfügbar** · **Trigger:** `/project-init` · **Risiko:** schreibend (nur nach Freigabe)

> Ein leeres Verzeichnis, ein gutes Gespräch, ein fertiges Fundament.

Führt ein interaktives Onboarding-Interview und scaffoldet ein neues Projekt komplett
— Struktur, Tooling, ops-Doku. Statt ein leeres Repo zu erraten, fragt `project-init`
gezielt nach Ziel, Stack, Struktur, Tooling, Docs, Secrets und Plattform, und schreibt
daraus ein vollständiges, konsistentes Grundgerüst inklusive `manifest.md` und
`tracking.md`, das jede spätere Session automatisch wieder einliest.

## Installation

### Voraussetzungen

- [Claude Code](https://claude.com/claude-code) installiert.
- Das Skript `scripts/init.ps1` ist PowerShell (5.1+ oder 7+). Unter Windows nativ
  vorhanden. Unter macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) — **plattformübergreifender Betrieb ist bisher nicht getestet**, entwickelt
  wurde unter Windows.

### Per Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/project-init ~/.claude/skills/project-init       # global
# oder projekt-lokal:
cp -r skill-shop-agents/skills/project-init <dein-projekt>/.claude/skills/project-init
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\project-init $HOME\.claude\skills\project-init
```

### Über den Skill-Shop

Der Skill-Shop (`shop/` im selben Repo) installiert diesen Skill mit einem Klick,
inklusive Pfad-Guards und Versions-Tracking beim Aktualisieren. Der Shop läuft nur
lokal auf deinem eigenen Rechner (kein Hosting) — siehe [`shop/README.md`](../../shop/README.md).

## Nutzung

In Claude Code, im (leeren) Zielprojekt:

```
/project-init                 # interaktives Onboarding im aktuellen Verzeichnis
/project-init <pfad>          # interaktives Onboarding in <pfad>
/project-init --help          # Kurzhilfe
```

Details zum Ablauf: [`SKILL.md`](SKILL.md).
