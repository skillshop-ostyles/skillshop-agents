# migrations-chirurg

✅ **Verfügbar** · **Trigger:** `/migrate` · **Risiko:** schreibend (Paket
entsteht immer im Arbeitsverzeichnis; ins Zielprojekt nur nach expliziter
Freigabe)

> Schema-Migrationen sind Operationen am offenen Herzen. Diese hier kommt mit
> Rollback.

Diffed zwei Schema-Stände (SQL-DDL oder Prisma) und generiert das komplette
Paket, das sonst niemand von Hand schreibt: Forward-Migration, Rollback,
Validierungs-Queries und ein Risiko-Protokoll mit expliziten
Datenverlust-Warnungen. **Führt niemals eine Migration aus** — nur Dateien.

## Installation

### Voraussetzungen

- [Claude Code](https://claude.com/claude-code) installiert.
- `scripts/schema-diff.ps1` ist PowerShell (5.1+ oder 7+). Unter Windows nativ
  vorhanden. Unter macOS/Linux via [PowerShell Core](https://github.com/PowerShell/PowerShell)
  (`pwsh`) — **plattformübergreifender Betrieb ist bisher nicht getestet**,
  entwickelt wurde unter Windows.
- Zwei Schema-Stände als Dateien (SQL-DDL oder Prisma) — kein Zugriff auf eine
  laufende Datenbank nötig oder vorgesehen.

### Per Terminal

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/migrations-chirurg ~/.claude/skills/migrations-chirurg       # global
# oder projekt-lokal:
cp -r skill-shop-agents/skills/migrations-chirurg <dein-projekt>/.claude/skills/migrations-chirurg
```

Windows (PowerShell):

```powershell
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
Copy-Item -Recurse skill-shop-agents\skills\migrations-chirurg $HOME\.claude\skills\migrations-chirurg
```

### Über den Skill-Shop

Der Skill-Shop (`shop/` im selben Repo) installiert diesen Skill mit einem Klick,
inklusive Pfad-Guards und Versions-Tracking beim Aktualisieren. Der Shop läuft nur
lokal auf deinem eigenen Rechner (kein Hosting) — siehe [`shop/README.md`](../../shop/README.md).

## Nutzung

In Claude Code:

```
/migrate                              # interaktiv
/migrate <alt> <neu> <dialekt>        # Diff + Paket generieren
/migrate --help
```

Details zum Ablauf (inkl. der Nie-Ausführen-Regel): [`SKILL.md`](SKILL.md).
