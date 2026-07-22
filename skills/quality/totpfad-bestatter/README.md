# totpfad-bestatter

✅ **Verfügbar** · **Trigger:** `/bury` · **Risiko:** schreibend (nur nach Freigabe)

> Toter Code stirbt nicht von allein. Jemand muss ihn beerdigen — mit Beweis.

Identifiziert nachweislich unerreichbaren Code (statische Nichterreichbarkeit +
optionale Coverage-/Log-Evidenz + Git-Alter) und bestattet ihn — **niemals
automatisch**, nur nach deiner expliziten Einzel-Freigabe pro Kandidat.

## Installation

### Voraussetzungen

- [Claude Code](https://claude.com/claude-code) installiert.
- `scripts/*.ps1` sind PowerShell (5.1+ oder 7+). Unter Windows nativ vorhanden.
  Unter macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) — **plattformübergreifender Betrieb ist bisher nicht getestet**,
  entwickelt wurde unter Windows.
- Für Alters-Evidenz: ein lokales Git-Repo (optional, sonst entfällt dieser Teil).

### Per Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/totpfad-bestatter ~/.claude/skills/totpfad-bestatter       # global
# oder projekt-lokal:
cp -r skill-shop-agents/skills/totpfad-bestatter <dein-projekt>/.claude/skills/totpfad-bestatter
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\totpfad-bestatter $HOME\.claude\skills\totpfad-bestatter
```

### Über den Skill-Shop

Der Skill-Shop (`shop/` im selben Repo) installiert diesen Skill mit einem Klick,
inklusive Pfad-Guards und Versions-Tracking beim Aktualisieren. Der Shop läuft nur
lokal auf deinem eigenen Rechner (kein Hosting) — siehe [`shop/README.md`](../../shop/README.md).

## Nutzung

In Claude Code:

```
/bury                                # interaktiv
/bury <dir>                          # nur statisch + git-Alter
/bury <dir> -coverage <report>       # plus Coverage-Evidenz
/bury <dir> -logs <logdir>           # plus Log-Evidenz
/bury --help
```

Details zum Ablauf (inkl. der Freigabe-Regel vor jeder Löschung):
[`SKILL.md`](SKILL.md).
