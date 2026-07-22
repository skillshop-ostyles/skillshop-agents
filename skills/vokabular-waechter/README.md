# vokabular-waechter

✅ **Verfügbar** · **Trigger:** `/vocab` · **Risiko:** read-only

> Customer, Client, Account, Kunde — vier Namen, ein Konzept, ein ständiges Missverständnis.

Erntet Bezeichner aus Code, Schema und API-Definitionen, clustert Synonyme zu
Domänen-Konzepten und schlägt je Cluster einen kanonischen Namen vor. Nie
werden Umbenennungen automatisch durchgeführt — nur Vorschlag + Impact-Schätzung.

## Installation

### Voraussetzungen

- [Claude Code](https://claude.com/claude-code) installiert.
- `scripts/term-harvest.ps1` ist PowerShell (5.1+ oder 7+). Unter Windows
  nativ vorhanden. Unter macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) — **plattformübergreifender Betrieb ist bisher nicht getestet**,
  entwickelt wurde unter Windows.

### Per Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/vokabular-waechter ~/.claude/skills/vokabular-waechter       # global
# oder projekt-lokal:
cp -r skill-shop-agents/skills/vokabular-waechter <dein-projekt>/.claude/skills/vokabular-waechter
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\vokabular-waechter $HOME\.claude\skills\vokabular-waechter
```

### Über den Skill-Shop

Der Skill-Shop (`shop/` im selben Repo) installiert diesen Skill mit einem Klick,
inklusive Pfad-Guards und Versions-Tracking beim Aktualisieren. Der Shop läuft nur
lokal auf deinem eigenen Rechner (kein Hosting) — siehe [`shop/README.md`](../../shop/README.md).

## Nutzung

In Claude Code:

```
/vocab                     # interaktiv
/vocab <dir>               # Vokabular-Analyse
/vocab <dir> "<domäne>"    # mit Domänen-Hinweis
/vocab --help
```

Details zum Ablauf: [`SKILL.md`](SKILL.md).
