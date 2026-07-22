# deps-erbschaft

✅ **Verfügbar** · **Trigger:** `/deps-audit` · **Risiko:** read-only

> Jede Dependency wurde angeheiratet. Zeit für die Erbschaftsfragen.

Beantwortet für jede direkte Dependency: Zweck (aus echten Nutzungsstellen), echte
Kopplungstiefe, Risiko, Austauschbarkeit und einen konkreten Exit-Plan.

## Installation

### Voraussetzungen

- [Claude Code](https://claude.com/claude-code) installiert.
- `scripts/*.ps1` sind PowerShell (5.1+ oder 7+). Unter Windows nativ vorhanden.
  Unter macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) — **plattformübergreifender Betrieb ist bisher nicht getestet**,
  entwickelt wurde unter Windows.
- Für Registry-Metadaten (optional): Internetzugang. Ohne Netz läuft der Skill mit
  einem klaren Hinweis weiter (Offline-Fallback ist Pflicht).

### Per Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/deps-erbschaft ~/.claude/skills/deps-erbschaft       # global
# oder projekt-lokal:
cp -r skill-shop-agents/skills/deps-erbschaft <dein-projekt>/.claude/skills/deps-erbschaft
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\deps-erbschaft $HOME\.claude\skills\deps-erbschaft
```

### Über den Skill-Shop

Der Skill-Shop (`shop/` im selben Repo) installiert diesen Skill mit einem Klick,
inklusive Pfad-Guards und Versions-Tracking beim Aktualisieren. Der Shop läuft nur
lokal auf deinem eigenen Rechner (kein Hosting) — siehe [`shop/README.md`](../../shop/README.md).

## Nutzung

In Claude Code:

```
/deps-audit                    # interaktiv, alle direkten Dependencies
/deps-audit <dir>              # Projekt analysieren
/deps-audit <dir> <dep> [...]  # nur genannte Dependencies
/deps-audit --help
```

Details zum Ablauf: [`SKILL.md`](SKILL.md).
