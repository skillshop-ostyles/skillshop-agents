# spec-luegendetektor

✅ **Verfügbar** · **Trigger:** `/spec-check` · **Risiko:** read-only

> Bevor du das Falsche baust: die Spec hält der Wahrheit stand?

Liest ein Korpus aus Specs/Tickets (Text-Dateien) und findet Widersprüche, Lücken,
Ambiguitäten, stille Annahmen und nicht testbare Aussagen — jeder Fund mit Zitat,
Fundstelle, Schweregrad und einer konkreten Klärungsfrage für den Product Owner.

## Installation

### Voraussetzungen

- [Claude Code](https://claude.com/claude-code) installiert.
- `scripts/intake.ps1` ist PowerShell (5.1+ oder 7+). Unter Windows nativ vorhanden.
  Unter macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) — **plattformübergreifender Betrieb ist bisher nicht getestet**,
  entwickelt wurde unter Windows.

### Per Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/spec-luegendetektor ~/.claude/skills/spec-luegendetektor       # global
# oder projekt-lokal:
cp -r skill-shop-agents/skills/spec-luegendetektor <dein-projekt>/.claude/skills/spec-luegendetektor
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\spec-luegendetektor $HOME\.claude\skills\spec-luegendetektor
```

### Über den Skill-Shop

Der Skill-Shop (`shop/` im selben Repo) installiert diesen Skill mit einem Klick,
inklusive Pfad-Guards und Versions-Tracking beim Aktualisieren. Der Shop läuft nur
lokal auf deinem eigenen Rechner (kein Hosting) — siehe [`shop/README.md`](../../shop/README.md).

## Nutzung

In Claude Code:

```
/spec-check                    # interaktiv: Spec-Verzeichnis erfragen
/spec-check <dir>              # alle Text-Dateien unter <dir> prüfen
/spec-check <datei1> <datei2>  # explizite Dateien prüfen
/spec-check --help             # Kurzhilfe
```

Details zum Ablauf: [`SKILL.md`](SKILL.md).
