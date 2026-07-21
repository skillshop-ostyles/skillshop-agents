# AGENTS

Zwei Dinge in einem Repo:

1. **Ein Skill-Programm** — 22 Claude-Code-Skills, die jahrzehntealte Entwickler-
   Schmerzen lösen (Git-Forensik, Test-Lücken, Security-Audits, Schema-Migrationen …).
   Zwei sind fertig (`elevate`, `project-init`), 20 sind als Sprint-Spezifikationen
   ausformuliert und werden schrittweise gebaut.
2. **Der Skill-Shop** (`shop/`) — Marktplatz und Fachgeschäft in einem, der diese
   Skills als Produkt anbietet: einzeln, in Bundles, facettiert durchsuchbar, mit
   Berater und Ein-Klick-Installation in ein Zielprojekt.

## Struktur

```
elevate/, project-init/   fertige Skills (SKILL.md + scripts/)
ops/                      die "Bibel": verbindliche Regeln + Sprint-Programm
  BIBEL.md                Master-Regeln fuers Skill-Programm
  SHOP-BIBEL.md           Master-Regeln fuer den Shop
  manifest.md             Ziel + Scope
  tracking.md             Sprint-Status
  sprints/                je Skill/Feature eine vollstaendige Spezifikation
shop/                     der Skill-Shop (Node/Express + SQLite, siehe shop/README.md)
```

## Schnellstart Shop

```bash
cd shop
npm install
npm run import   # baut die Produkt-DB aus den Skill-Ordnern + catalog/
npm start        # http://127.0.0.1:4711
```

Details: [`shop/README.md`](shop/README.md).

## Regeln

Verbindlich sind [`ops/BIBEL.md`](ops/BIBEL.md) und
[`ops/SHOP-BIBEL.md`](ops/SHOP-BIBEL.md). Kurz:

- **Lokal-only** — dieses Repo hat keinen Remote und bekommt keinen.
- **`~/.claude/` ist unantastbar** — kein Skript und kein Installer verändert es
  jemals (case-insensitiver Pfad-Guard, getestet).
- Deutsch, direkt; Simplicity First; chirurgische Änderungen; jeder Fix mit Test.

## Qualität

Der Shop hat eine node:test-Suite (`npm test` in `shop/`) und ESLint
(`npm run lint`). `.editorconfig` + `.gitattributes` halten Format und Zeilenenden
konsistent.
