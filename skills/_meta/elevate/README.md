# elevate

✅ **Verfügbar** · **Trigger:** `/elevate` · **Risiko:** schreibend (nur nach Freigabe)

> Dein Projekt verdient Enterprise-Niveau — ohne dass du dafür bezahlst, es selbst zu
> erfinden.

Auditiert ein Projekt gegen 7 Enterprise-Dimensionen (Tests+Coverage, Lint/Format,
CI/CD, Secrets-Hygiene, Docs, Type-Safety, Dependency-Audit) und hebt es an — nur die
Teile, die du einzeln freigibst. Generisch über Stacks und CI-Systeme, läuft auch
komplett lokal.

## Installation

### Voraussetzungen

- [Claude Code](https://claude.com/claude-code) installiert.
- Die Skripte in `scripts/*.ps1` sind PowerShell (5.1+ oder 7+). Unter Windows nativ
  vorhanden. Unter macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) — **plattformübergreifender Betrieb ist bisher nicht getestet**, entwickelt
  wurde unter Windows.

### Per Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/elevate ~/.claude/skills/elevate       # global, alle Projekte
# oder projekt-lokal:
cp -r skill-shop-agents/skills/elevate <dein-projekt>/.claude/skills/elevate
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\elevate $HOME\.claude\skills\elevate
```

### Über den Skill-Shop

Der Skill-Shop (`shop/` im selben Repo) installiert diesen Skill mit einem Klick,
inklusive Pfad-Guards und Versions-Tracking beim Aktualisieren. Der Shop läuft nur
lokal auf deinem eigenen Rechner (kein Hosting) — siehe [`shop/README.md`](../../shop/README.md).

## Nutzung

In Claude Code, im Zielprojekt:

```
/elevate                 # audit + elevate aktuelles Verzeichnis
/elevate <pfad>          # audit + elevate <pfad>
/elevate --help          # Kurzhilfe
```

Details zum Ablauf: [`SKILL.md`](SKILL.md).
