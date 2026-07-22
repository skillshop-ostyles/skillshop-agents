# zeitbomben-scanner

✅ **Verfügbar** · **Trigger:** `/timebomb` · **Risiko:** read-only

> Jede Codebase tickt. Diese hier weißt du, wann.

Findet hartkodierte Ablaufdaten, Ablauf-Schlüsselwörter, verrottete
"temporär"-Marker (mit Git-Alter) und 32-Bit-Zeit-Verdacht — sortiert nach
Zünddatum.

## Installation

### Voraussetzungen

- [Claude Code](https://claude.com/claude-code) installiert.
- `scripts/timebomb-scan.ps1` ist PowerShell (5.1+ oder 7+). Unter Windows
  nativ vorhanden. Unter macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) — **plattformübergreifender Betrieb ist bisher nicht getestet**,
  entwickelt wurde unter Windows.
- Für das Alter der Provisorien-Marker: ein lokales Git-Repo (optional, sonst
  entfällt nur diese Auswertung).

### Per Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/zeitbomben-scanner ~/.claude/skills/zeitbomben-scanner       # global
# oder projekt-lokal:
cp -r skill-shop-agents/skills/zeitbomben-scanner <dein-projekt>/.claude/skills/zeitbomben-scanner
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\zeitbomben-scanner $HOME\.claude\skills\zeitbomben-scanner
```

### Über den Skill-Shop

Der Skill-Shop (`shop/` im selben Repo) installiert diesen Skill mit einem Klick,
inklusive Pfad-Guards und Versions-Tracking beim Aktualisieren. Der Shop läuft nur
lokal auf deinem eigenen Rechner (kein Hosting) — siehe [`shop/README.md`](../../shop/README.md).

## Nutzung

In Claude Code:

```
/timebomb               # interaktiv
/timebomb <dir>         # Projekt scannen
/timebomb --help
```

Details zum Ablauf: [`SKILL.md`](SKILL.md).
