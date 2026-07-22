# wissens-testament

✅ **Verfügbar** · **Trigger:** `/testament` · **Risiko:** read-only

> Wenn der Kopf mit dem Wissen geht, muss das Wissen vorher raus.

Mint Git-Ownership (Blame-Anteile, Hotspots, Alleinwissen), um zu finden, wo das
Alleinwissen einer Person steckt, und führt darauf ein gezieltes,
evidenzverankertes Übergabe-Interview.

## Installation

### Voraussetzungen

- [Claude Code](https://claude.com/claude-code) installiert.
- `scripts/ownership.ps1` ist PowerShell (5.1+ oder 7+). Unter Windows nativ
  vorhanden. Unter macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) — **plattformübergreifender Betrieb ist bisher nicht getestet**,
  entwickelt wurde unter Windows.
- Ein lokales Git-Repo mit Historie als Analyseziel.

### Per Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/wissens-testament ~/.claude/skills/wissens-testament       # global
# oder projekt-lokal:
cp -r skill-shop-agents/skills/wissens-testament <dein-projekt>/.claude/skills/wissens-testament
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\wissens-testament $HOME\.claude\skills\wissens-testament
```

### Über den Skill-Shop

Der Skill-Shop (`shop/` im selben Repo) installiert diesen Skill mit einem Klick,
inklusive Pfad-Guards und Versions-Tracking beim Aktualisieren. Der Shop läuft nur
lokal auf deinem eigenen Rechner (kein Hosting) — siehe [`shop/README.md`](../../shop/README.md).

## Nutzung

In Claude Code:

```
/testament                       # interaktiv
/testament <repo> <autor>        # Testament für <autor> aus <repo>
/testament <repo> -list          # Autoren mit Anteilen listen
/testament --help
```

Details zum Ablauf: [`SKILL.md`](SKILL.md).
