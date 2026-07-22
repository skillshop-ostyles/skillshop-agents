# doku-drift-detektor

✅ **Verfügbar** · **Trigger:** `/doc-drift` · **Risiko:** read-only

> Dein README lügt seit sechs Monaten. Zeit, es zu ertappen.

Extrahiert prüfbare Doku-Behauptungen — Pfade, Kommandos, Config-Schlüssel,
Endpoints, Versionen, Symbol-Referenzen — und hält jede statisch gegen die
Code-Realität. Dokumentierte Kommandos werden niemals ausgeführt.

## Installation

### Voraussetzungen

- [Claude Code](https://claude.com/claude-code) installiert.
- `scripts/claim-extract.ps1` ist PowerShell (5.1+ oder 7+). Unter Windows
  nativ vorhanden. Unter macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) — **plattformübergreifender Betrieb ist bisher nicht getestet**,
  entwickelt wurde unter Windows.

### Per Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/doku-drift-detektor ~/.claude/skills/doku-drift-detektor       # global
# oder projekt-lokal:
cp -r skill-shop-agents/skills/doku-drift-detektor <dein-projekt>/.claude/skills/doku-drift-detektor
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\doku-drift-detektor $HOME\.claude\skills\doku-drift-detektor
```

### Über den Skill-Shop

Der Skill-Shop (`shop/` im selben Repo) installiert diesen Skill mit einem Klick,
inklusive Pfad-Guards und Versions-Tracking beim Aktualisieren. Der Shop läuft nur
lokal auf deinem eigenen Rechner (kein Hosting) — siehe [`shop/README.md`](../../shop/README.md).

## Nutzung

In Claude Code:

```
/doc-drift               # interaktiv
/doc-drift <dir>         # Repo-Doku prüfen
/doc-drift --help
```

Details zum Ablauf: [`SKILL.md`](SKILL.md).
