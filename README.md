# AGENTS

22 Claude-Code-Skills, die jahrzehntealte Entwickler-Schmerzen lösen — Git-Forensik,
Test-Lücken, Security-Audits, Schema-Migrationen und mehr. **2 sind fertig und
installierbar, 20 sind vollständig spezifiziert** und werden schrittweise gebaut. Jeder
Skill folgt demselben Muster: `SKILL.md` (Claude-Code-Instruktion) + `scripts/` +
`README.md` (Installation).

Zwei Dinge in einem Repo:

1. **Das Skill-Programm** (`skills/`) — die Skills selbst, einzeln installierbar.
2. **Der Skill-Shop** (`shop/`) — Marktplatz und Fachgeschäft in einem, das diese
   Skills als Produkt anbietet: einzeln, in Bundles, facettiert durchsuchbar, mit
   Berater und Ein-Klick-Installation in ein Zielprojekt. Läuft **nur lokal**
   (`127.0.0.1`, kein Hosting — Begründung in [`ops/SHOP-BIBEL.md`](ops/SHOP-BIBEL.md) § 9).

## Skills installieren

Jeder Skill hat eine eigene `README.md` mit Terminal-Befehlen für macOS/Linux und
Windows, z. B. [`skills/elevate/README.md`](skills/elevate/README.md). Kurzform:

```bash
git clone https://github.com/skillshop-ostyles/skill-shop-agents.git
cp -r skill-shop-agents/skills/elevate ~/.claude/skills/elevate
```

Alternativ: über den lokalen Skill-Shop installieren (Pfad-Guards, Update-Tracking,
Berater) — siehe [`shop/README.md`](shop/README.md).

## Struktur

```
skills/                   ein Ordner je Skill (SKILL.md + scripts/ + README.md)
  elevate/, project-init/   fertig, installierbar
  <20 weitere>/              geplant — Platzhalter mit Link zur Sprint-Spec
ops/                      die "Bibel": verbindliche Regeln + Sprint-Programm
  BIBEL.md                Master-Regeln fuers Skill-Programm
  SHOP-BIBEL.md           Master-Regeln fuer den Shop
  manifest.md             Ziel + Scope
  tracking.md             Sprint-Status (Quelle der Wahrheit fuer "fertig"/"geplant")
  sprints/                je Skill/Feature eine vollstaendige Spezifikation
shop/                     der Skill-Shop (Node/Express + SQLite, siehe shop/README.md)
```

## Schnellstart Shop

```bash
cd shop
npm install
npm run import   # baut die Produkt-DB aus skills/ + shop/catalog/
npm start        # http://127.0.0.1:4711
```

Details: [`shop/README.md`](shop/README.md).

## Regeln

Verbindlich sind [`ops/BIBEL.md`](ops/BIBEL.md) und
[`ops/SHOP-BIBEL.md`](ops/SHOP-BIBEL.md). Kurz:

- **`~/.claude/` ist unantastbar** — kein Skript und kein Installer verändert es
  jemals (case-insensitiver Pfad-Guard, getestet).
- Deutsch, direkt; Simplicity First; chirurgische Änderungen; jeder Fix mit Test.
- Ehrlichkeits-Prinzip: Status kommt aus `ops/tracking.md`, keine Fake-Reviews, keine
  erfundenen Zahlen.

## Qualität

Der Shop hat eine node:test-Suite (`npm test` in `shop/`) und ESLint
(`npm run lint`). `.editorconfig` + `.gitattributes` halten Format und Zeilenenden
konsistent.

## Lizenz

[MIT](LICENSE).
