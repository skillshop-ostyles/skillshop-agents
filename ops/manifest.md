# Manifest — AGENTS Skill-Programm

## Ziel

10 neue KI-Skills bauen, die klassische Entwickler-Schmerzen lösen, welche erst durch
LLMs automatisierbar wurden. Jeder Skill folgt dem bestehenden Muster
(`SKILL.md` + `scripts/*.ps1`, siehe `skills/elevate/`, `skills/project-init/`) und wird in genau
einem Sprint umgesetzt.

## Scope

| # | Skill | Trigger | Kern |
|---|---|---|---|
| 1 | intent-archaeologie | /intent | Warum existiert dieser Code? Absichten aus Git-Historie rekonstruieren |
| 2 | spec-luegendetektor | /spec-check | Widersprüche, Lücken, Ambiguitäten in Specs/Tickets finden |
| 3 | seiteneffekt-radar | /blast | Blast-Radius eines geplanten Changes vorhersagen |
| 4 | konsistenz-enforcer | /consist | Semantisch gleiche Geschäftsregeln finden, Divergenzen melden |
| 5 | totpfad-bestatter | /bury | Nachweislich toten Code mit Evidenz identifizieren |
| 6 | deps-erbschaft | /deps-audit | Jede Dependency: Zweck, Risiko, Austauschbarkeit, Exit-Plan |
| 7 | wissens-testament | /testament | Kopf-Wissen eines Entwicklers per Interview + Mining konservieren |
| 8 | repro-automat | /repro | Aus vagem Bug-Report ein minimales lauffähiges Repro bauen |
| 9 | prod-spiegel | /mirror | Code-Erwartung vs. Log-Realität abgleichen |
| 10 | migrations-chirurg | /migrate | Schema-Diff → Migration + Rollback + Validierung |
| 11 | zeitbomben-scanner | /timebomb | Hartkodierte Daten, ablaufende Annahmen, verrottete Provisorien finden |
| 12 | doku-drift-detektor | /doc-drift | Doku-Behauptungen statisch gegen die Code-Realität prüfen |
| 13 | vokabular-waechter | /vocab | Synonyme/Homonyme für Domänen-Konzepte finden, Kanon vorschlagen |
| 14 | konfig-kartograf | /config-map | Konfig-Oberfläche kartieren: definiert vs. gelesen, Waisen, Crash-Kandidaten |
| 15 | test-luecken-kartograf | /testgap | Ungetestetes VERHALTEN (nicht Zeilen) je öffentlichem Symbol finden |
| 16 | ausfall-simulant | /failsim | Fehlerpfade je Ausfallszenario statisch zu Ende denken |
| 17 | api-vertrags-waechter | /api-diff | Breaking Changes zwischen zwei API-Ständen + Migrations-Notizen |
| 18 | berechtigungs-roentgen | /authz | Permission-Matrix aus dem Code, ungeschützte Endpoints, Inkonsistenzen |
| 19 | datenspuren-verfolger | /pii-trace | PII-Felder und ihre Senken (Logs, Dritt-APIs, Exporte) kartieren |
| 20 | onboarding-pfadfinder | /onboard | Geführte Lese-Tour durch die Codebase für neue Devs generieren |

## Skill-Shop (Sprints 21-25)

Plattform: Marktplatz + Fachgeschäft in einem — Skills als Produkt, einzeln und in
Bundles, facettiert nach Usecase/Thema/Stichwort/Ziel/Branche/Tätigkeit.
"Kauf" = Installation in ein Zielprojekt (`<ziel>/.claude/skills/`), Phase 1
kostenlos, Monetarisierung im Datenmodell vorbereitet. Stack: Express +
better-sqlite3 (FTS5), statisches Vanilla-Frontend, localhost-only.
Masterspezifikation: `ops/SHOP-BIBEL.md`.

| Sprint | Inhalt |
|---|---|
| 21 | shop-fundament — Node-Gerüst, Schema, Importer, kuratierter Katalog (22 Skills, Taxonomie, 6 Bundles) |
| 22 | shop-katalog — API + Landing, Katalog (Facetten/Suche), Produkt- und Bundle-Seiten |
| 23 | shop-checkout-installer — Warenkorb, Kasse, Installer (Schutz-Guard), Bibliothek, Merkliste |
| 24 | shop-berater-bundles — regelbasierter Berater, Bundle-Kauf, Landing-Feinschliff |
| 25 | shop-haertung — Test-Suite, Pricing-Flag, README, Performance, Gesamtabnahme |

## Constraints (fix)

- Repo lokal-only: kein Remote, kein Push — niemals.
- `~/.claude/` wird von nichts in diesem Repo verändert (Schutzregel, siehe BIBEL § 2).
- Ausführendes Modell der Sprints: Sonnet. Regeln: `ops/BIBEL.md`.
- Skills sind gegenüber analysierten Fremdprojekten read-only (Ausnahmen nur mit
  expliziter User-Freigabe, geregelt in den Sprint-Files 05 und 10).

## Struktur

- `ops/BIBEL.md` — Master-Regeln, Skill-Anatomie, Sprint-/Test-Protokoll, DoD
- `ops/tracking.md` — Sprint-Status + Blocker
- `ops/sprints/sprint-NN-<skill>.md` — je Sprint die vollständige Spezifikation
- `skills/<skill-name>/` — die Skills (fertig oder als Platzhalter, entstehen sprintweise)
