# repro-automat

✅ **Verfügbar** · **Trigger:** `/repro` · **Risiko:** schreibend (nur im eigenen
`repro/`-Arbeitsordner, niemals im Zielprojekt)

> "Geht nicht" ist keine Antwort. Ein lauffähiges Repro schon.

Verwandelt einen vagen Bug-Report in einen minimalen, tatsächlich AUSGEFÜHRTEN
Repro-Test (max. 5 Versuche) — oder eine präzise Liste, welche Information zum
Reproduzieren fehlt.

## Installation

### Voraussetzungen

- [Claude Code](https://claude.com/claude-code) installiert.
- `scripts/env-snapshot.ps1` ist PowerShell (5.1+ oder 7+). Unter Windows nativ
  vorhanden. Unter macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) — **plattformübergreifender Betrieb ist bisher nicht getestet**,
  entwickelt wurde unter Windows.
- Die zum Zielprojekt passende Laufzeit (Node/Python/.NET/Go), damit das
  generierte Repro-Artefakt ausgeführt werden kann.

### Per Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/repro-automat ~/.claude/skills/repro-automat       # global
# oder projekt-lokal:
cp -r skill-shop-agents/skills/repro-automat <dein-projekt>/.claude/skills/repro-automat
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\repro-automat $HOME\.claude\skills\repro-automat
```

### Über den Skill-Shop

Der Skill-Shop (`shop/` im selben Repo) installiert diesen Skill mit einem Klick,
inklusive Pfad-Guards und Versions-Tracking beim Aktualisieren. Der Shop läuft nur
lokal auf deinem eigenen Rechner (kein Hosting) — siehe [`shop/README.md`](../../shop/README.md).

## Nutzung

In Claude Code:

```
/repro                          # interaktiv
/repro <repo>                   # Report wird abgefragt
/repro <repo> <report-datei>    # Report aus Datei
/repro --help
```

Details zum Ablauf: [`SKILL.md`](SKILL.md).
