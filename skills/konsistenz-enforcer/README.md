# konsistenz-enforcer

✅ **Verfügbar** · **Trigger:** `/consist` · **Risiko:** read-only

> Eine Regel, vierzehn Implementierungen — und niemand weiß, welche stimmt.

Findet semantisch gleiche Geschäftsregeln in unterschiedlichem Code (nicht
Text-Duplikate) und meldet Divergenzen zwischen ihren Implementierungen mit einem
Single-Source-of-Truth-Vorschlag.

## Installation

### Voraussetzungen

- [Claude Code](https://claude.com/claude-code) installiert.
- `scripts/rule-candidates.ps1` ist PowerShell (5.1+ oder 7+). Unter Windows nativ
  vorhanden. Unter macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) — **plattformübergreifender Betrieb ist bisher nicht getestet**,
  entwickelt wurde unter Windows.

### Per Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/konsistenz-enforcer ~/.claude/skills/konsistenz-enforcer       # global
# oder projekt-lokal:
cp -r skill-shop-agents/skills/konsistenz-enforcer <dein-projekt>/.claude/skills/konsistenz-enforcer
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\konsistenz-enforcer $HOME\.claude\skills\konsistenz-enforcer
```

### Über den Skill-Shop

Der Skill-Shop (`shop/` im selben Repo) installiert diesen Skill mit einem Klick,
inklusive Pfad-Guards und Versions-Tracking beim Aktualisieren. Der Shop läuft nur
lokal auf deinem eigenen Rechner (kein Hosting) — siehe [`shop/README.md`](../../shop/README.md).

## Nutzung

In Claude Code:

```
/consist                  # interaktiv
/consist <dir>            # ganzes Verzeichnis
/consist <dir> "<fokus>"  # mit fachlichem Fokus
/consist --help
```

Details zum Ablauf: [`SKILL.md`](SKILL.md).
