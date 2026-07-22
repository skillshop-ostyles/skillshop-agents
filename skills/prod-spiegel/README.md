# prod-spiegel

✅ **Verfügbar** · **Trigger:** `/mirror` · **Risiko:** read-only

> Was dein Code verspricht, und was Prod wirklich tut, sind zwei Geschichten.

Gleicht exportierte Logs statistisch gegen Code-Erwartungen ab: tote Features,
verschluckte Fehler, unerwartete Hot Paths, "unmögliche" Zustände, die trotzdem
feuern. Funktioniert komplett offline auf exportierten Log-Dateien.

## Installation

### Voraussetzungen

- [Claude Code](https://claude.com/claude-code) installiert.
- `scripts/*.ps1` sind PowerShell (5.1+ oder 7+). Unter Windows nativ vorhanden.
  Unter macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) — **plattformübergreifender Betrieb ist bisher nicht getestet**,
  entwickelt wurde unter Windows.
- Exportierte Log-Dateien (`.log`/`.txt`/`.jsonl`/`.json`) — keine Live-Anbindung
  an Observability-Plattformen nötig oder unterstützt.

### Per Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/prod-spiegel ~/.claude/skills/prod-spiegel       # global
# oder projekt-lokal:
cp -r skill-shop-agents/skills/prod-spiegel <dein-projekt>/.claude/skills/prod-spiegel
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\prod-spiegel $HOME\.claude\skills\prod-spiegel
```

### Über den Skill-Shop

Der Skill-Shop (`shop/` im selben Repo) installiert diesen Skill mit einem Klick,
inklusive Pfad-Guards und Versions-Tracking beim Aktualisieren. Der Shop läuft nur
lokal auf deinem eigenen Rechner (kein Hosting) — siehe [`shop/README.md`](../../shop/README.md).

## Nutzung

In Claude Code:

```
/mirror                          # interaktiv
/mirror <repo> <logdir>          # Abgleich Code vs. Logs
/mirror --help
```

Details zum Ablauf: [`SKILL.md`](SKILL.md).
