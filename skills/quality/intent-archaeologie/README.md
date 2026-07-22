# intent-archaeologie

✅ **Verfügbar** · **Trigger:** `/intent` · **Risiko:** read-only

> Warum existiert dieser Code? Dein Repo erinnert sich.

Rekonstruiert die Absichts-Geschichte einer Datei aus Git-Historie, Blame und
Ticket-IDs — mit Commit-Belegen. Analysiert eine Datei (optional ein Symbol darin)
pro Lauf und liefert eine chronologische Warum-Story samt Konfidenz-Stufen statt
Vermutungen.

## Installation

### Voraussetzungen

- [Claude Code](https://claude.com/claude-code) installiert.
- `scripts/git-mine.ps1` ist PowerShell (5.1+ oder 7+). Unter Windows nativ
  vorhanden. Unter macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) — **plattformübergreifender Betrieb ist bisher nicht getestet**, entwickelt
  wurde unter Windows.
- Ein lokales Git-Repo mit Historie als Analyseziel.

### Per Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/intent-archaeologie ~/.claude/skills/intent-archaeologie       # global
# oder projekt-lokal:
cp -r skill-shop-agents/skills/intent-archaeologie <dein-projekt>/.claude/skills/intent-archaeologie
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\intent-archaeologie $HOME\.claude\skills\intent-archaeologie
```

### Über den Skill-Shop

Der Skill-Shop (`shop/` im selben Repo) installiert diesen Skill mit einem Klick,
inklusive Pfad-Guards und Versions-Tracking beim Aktualisieren. Der Shop läuft nur
lokal auf deinem eigenen Rechner (kein Hosting) — siehe [`shop/README.md`](../../shop/README.md).

## Nutzung

In Claude Code:

```
/intent                          # interaktiv: Repo, Datei, optional Symbol erfragen
/intent <repo> <datei>           # Datei-Analyse
/intent <repo> <datei> <symbol>  # Symbol-Analyse
/intent --help                   # Kurzhilfe
```

Details zum Ablauf: [`SKILL.md`](SKILL.md).
