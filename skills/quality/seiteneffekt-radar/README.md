# seiteneffekt-radar

✅ **Verfügbar** · **Trigger:** `/blast` · **Risiko:** read-only

> Kleiner Change, große Überraschung? Nicht mehr.

Kombiniert statische Referenz-Suche mit historischer Co-Change-Analyse (welche
Dateien in der Vergangenheit fast immer gemeinsam mit dem Ziel geändert wurden) zu
einem risikogestuften Blast-Radius-Report vor einem geplanten Change.

## Installation

### Voraussetzungen

- [Claude Code](https://claude.com/claude-code) installiert.
- `scripts/*.ps1` sind PowerShell (5.1+ oder 7+). Unter Windows nativ vorhanden.
  Unter macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) — **plattformübergreifender Betrieb ist bisher nicht getestet**,
  entwickelt wurde unter Windows.
- Ein lokales Git-Repo als Analyseziel (Co-Change-Analyse; die Referenz-Suche
  funktioniert auch ohne Git).

### Per Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/seiteneffekt-radar ~/.claude/skills/seiteneffekt-radar       # global
# oder projekt-lokal:
cp -r skill-shop-agents/skills/seiteneffekt-radar <dein-projekt>/.claude/skills/seiteneffekt-radar
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\seiteneffekt-radar $HOME\.claude\skills\seiteneffekt-radar
```

### Über den Skill-Shop

Der Skill-Shop (`shop/` im selben Repo) installiert diesen Skill mit einem Klick,
inklusive Pfad-Guards und Versions-Tracking beim Aktualisieren. Der Shop läuft nur
lokal auf deinem eigenen Rechner (kein Hosting) — siehe [`shop/README.md`](../../shop/README.md).

## Nutzung

In Claude Code:

```
/blast                          # interaktiv
/blast <repo> <datei> [...]     # Blast-Radius für geplanten Change an <datei>
/blast --help
```

Details zum Ablauf: [`SKILL.md`](SKILL.md).
