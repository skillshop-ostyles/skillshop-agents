# Sprint 06 — deps-erbschaft (/deps-audit)

Regeln: `ops/BIBEL.md` gilt vollständig.

## 1. Problem

Dependencies werden angeheiratet, nie geprüft und nie geschieden. Nach Jahren weiß
niemand: Warum ist das drin? Was nutzt es wirklich? Was passiert, wenn der Maintainer
aufhört? `npm audit` findet CVEs, aber niemand beantwortet die Erbschaftsfragen:
Zweck, tatsächliche Nutzungstiefe, Austauschbarkeit, Exit-Plan. Dafür muss man
Nutzungsstellen im eigenen Code fachlich verstehen — LLM-Arbeit.

## 2. Nutzen

Vorher: Dependency-Entscheidungen ("können wir X rauswerfen/ersetzen?") dauern Tage
Recherche. Nachher: lebendes Erbschafts-Register — pro Dependency Zweck, Nutzungsorte,
Risiko, Austauschaufwand, konkreter Exit-Plan. Profiteure: Tech Leads
(Upgrade-/Migrations-Planung), Security, jeder `npm install`-Zauderer.

## 3. Scope / Nicht-Scope

**Scope:** Manifest + Lockfile-Parsing (npm/pnpm/yarn, pip/poetry, cargo, go.mod),
Nutzungsstellen-Scan im eigenen Code, optionale Registry-Metadaten (npm view /
PyPI JSON) mit Offline-Fallback.
**Nicht-Scope:** Kein CVE-Scan (dafür gibt es `npm audit` & Co — nicht duplizieren,
nur auf vorhandene Audit-Ausgabe verweisen, falls der User sie bereitstellt). Keine
transitiven Dependencies in der Tiefenanalyse (nur zählen). Read-only.

## 4. Skill-Spezifikation

Ordner: `deps-erbschaft/`

Frontmatter:

```yaml
---
name: deps-erbschaft
description: "Dependency inheritance audit: for every direct dependency answers the questions nobody asks - why is it here (from actual usage sites), how deep is the coupling, how replaceable is it, and what is the concrete exit plan. Parses manifests/lockfiles, scans usage, optionally enriches with registry metadata (offline-safe). Read-only. Trigger: /deps-audit"
trigger: /deps-audit
---
```

Invocation-Steps:

1. `--help` → Usage, stopp.
2. Klären: `-ProjectDir`; optional Fokus auf einzelne Dependencies. Bestätigen.
3. `scripts/deps-inventory.ps1` ausführen.
4. Optional (Netz verfügbar + User nicht dagegen): `scripts/registry-meta.ps1`.
5. LLM-Analyse gemäß § 6, Report `deps-erbschaft-report.md`.

Usage:

```
/deps-audit                    # interaktiv, alle direkten Dependencies
/deps-audit <dir>              # Projekt analysieren
/deps-audit <dir> <dep> [...]  # nur genannte Dependencies
/deps-audit --help
```

## 5. Collector-Skripte

### scripts/deps-inventory.ps1

Parameter: `-ProjectDir` (Pflicht), `-Only` (optional, String-Array von
Dependency-Namen), `-Exclude`/`-Extensions` (Defaults wie Sprint 03).

Read-only. Drei Schritte:

1. **Manifest-Parsing**: package.json (dependencies/devDependencies getrennt),
   pyproject.toml / requirements.txt, Cargo.toml, go.mod — was vorhanden ist.
   Pro Dependency: Name, deklarierte Version, dev/prod.
2. **Lockfile-Zählung**: Anzahl transitiver Pakete gesamt (package-lock/pnpm-lock/
   yarn.lock: Paket-Einträge zählen; poetry.lock/Cargo.lock/go.sum analog).
   Nur Zählwert, keine Tiefenanalyse.
3. **Nutzungsstellen-Scan**: pro direkter Dependency Import-/Require-/use-Zeilen im
   eigenen Code (`from '<dep>'`, `require('<dep>')`, `import <dep>`, `use <dep>` —
   inkl. Subpfade `<dep>/...`). Pro Dependency: Trefferliste (Datei, Zeile, Text)
   und `usageCount`.

JSON-Schema (Beispiel):

```json
{
  "manifests": ["package.json"],
  "dependencies": [
    {
      "name": "lodash", "declared": "^4.17.21", "scope": "prod",
      "usage": [ { "file": "src/util/merge.ts", "line": 3, "text": "import { merge } from 'lodash'" } ],
      "usageCount": 1
    }
  ],
  "transitiveCount": 843,
  "unusedDeclared": ["left-pad"]
}
```

`unusedDeclared` = deklariert, aber 0 Nutzungsstellen (eigener Befund-Typ).

### scripts/registry-meta.ps1

Parameter: `-Names` (Pflicht, String-Array), `-Ecosystem` (npm|pypi, Default npm),
`-TimeoutSec` (Default 10).

Read-only, Netz-Zugriff. npm: `npm view <name> time.modified maintainers license
--json` (npm-CLI vorausgesetzt; fehlt sie → Fallback `Invoke-RestMethod
https://registry.npmjs.org/<name>`); PyPI: `https://pypi.org/pypi/<name>/json`.
Pro Paket: letztes Release-Datum, Maintainer-Anzahl, Lizenz. JEDER Fehler
(offline, 404, Timeout) → Feld `meta: null` + `metaError` mit Grund, exit 0
(Offline-Fallback ist Pflicht, kein Abbruch).

## 6. LLM-Analyse-Steps

Pro direkter Dependency:

1. **Zweck** (aus den Nutzungsstellen): Wofür wird sie WIRKLICH verwendet — die
   ehrliche Antwort ist oft "für eine einzige Funktion". Konfidenz angeben.
2. **Kopplungstiefe**: `oberflächlich` (wenige Stellen, einfache Aufrufe) /
   `mittel` / `tief` (API-Typen in eigenen Signaturen, Vererbung, Konfig-Magie).
   Beleg: usageCount + charakteristische Fundstellen.
3. **Risiko**: Kombination aus Kopplungstiefe, Wartungssignal (letztes Release,
   Maintainer — falls Meta vorhanden), Lizenz-Auffälligkeit (GPL in proprietärem
   Kontext o. ä. — nur Hinweis, keine Rechtsberatung), `unusedDeclared`.
4. **Austauschbarkeit + Exit-Plan**: konkrete Alternative(n) benennen (Stdlib-Ersatz
   zuerst prüfen!), Aufwandsschätzung in Kategorien (Stunden/Tage/Wochen), die
   ersten 3 konkreten Schritte des Exits.
5. Report: Kurzfassung (Bestand, Top-3-Risiken, Quick Wins wie unusedDeclared) →
   Register-Tabelle (Name, Zweck, Kopplung, Risiko, Austauschbarkeit) →
   Detail-Abschnitte pro auffälliger Dependency → Offene Fragen.
6. Evidenz-Pflicht: Zweck/Kopplung immer mit Fundstellen; Wartungsaussagen nur mit
   Registry-Daten (sonst "keine Metadaten verfügbar" — nie raten).

## 7. Edge-Cases

| Fall | Verhalten |
|---|---|
| Offline / Registry down | registry-meta liefert metaError, Analyse läuft ohne Wartungssignal weiter |
| Monorepo mit mehreren Manifests | Alle finden, pro Manifest gruppieren |
| Dependency nur in Config genutzt (z. B. eslint-Plugins) | usageCount 0 im Code ist dann KEIN unused — LLM prüft Config-Dateien (json/yaml/rc) bevor unusedDeclared bestätigt wird |
| Alias-Importe (`@scope/paket`) | Scan-Muster müssen Scoped Packages abdecken |
| Sehr viele Dependencies (> 50) | Register-Tabelle für alle, Detail-Analyse nur Top 15 nach Risiko; Rest auf Anfrage |
| Kein Manifest gefunden | Sauber melden, stopp |

## 8. Testplan

Smoke: Fixture `deps-erbschaft/tests/fixture/` mit Mini-package.json (2 deps, davon
1 ungenutzt) + 1 Quelldatei, die die andere importiert. Dann:

```powershell
& .\deps-erbschaft\scripts\deps-inventory.ps1 -ProjectDir ".\deps-erbschaft\tests\fixture"
```

Erwartung: exit 0, JSON valide, genutzte Dependency mit 1 Fundstelle, ungenutzte in
`unusedDeclared`. registry-meta gegen ein reales bekanntes Paket (z. B. `lodash`)
UND gegen einen erfundenen Namen (→ metaError, exit 0) testen.

Akzeptanz (dreamzzz-api): Komplettlauf. Erwartung: alle direkten Dependencies im
Register, 3 Zweck-Aussagen stichprobenartig gegen Fundstellen verifiziert,
unusedDeclared-Funde manuell gegengeprüft (Config-Nutzung beachten, § 7).

Negativ: ungültiger Pfad → exit != 0.

## 9. DoD-Checkliste

- [x] SKILL.md vollständig
- [x] deps-inventory.ps1 (Manifeste, Lock-Zählung, Nutzungs-Scan, unusedDeclared)
- [x] registry-meta.ps1 mit Offline-Fallback (beide Testfälle bestanden)
- [x] Fixture angelegt, Smoke bestanden
- [x] Akzeptanz-Lauf dokumentiert (Stichproben verifiziert)
- [x] Negativ-Test bestanden
- [x] Report erfüllt BIBEL § 4
- [x] tracking.md aktualisiert, Commit `sprint-06: deps-erbschaft implementiert`

## 10. Entscheidungen während der Umsetzung

1. **Skill-Ordner-Pfad**: `skills/deps-erbschaft/` (BIBEL-§-3-Konvention seit
   Sprint 29).
2. **`ConvertFrom-Json`-Bug mit npm-Lockfile-v3 gefunden und behoben**: npm
   `lockfileVersion: 3` trägt den Root-Package-Eintrag unter dem Key `""` (leerer
   String) im `packages`-Objekt. PowerShell 5.1s `ConvertFrom-Json` baut daraus ein
   `PSCustomObject`, das keine leeren Property-Namen erlaubt → harter Absturz
   ("Das Argument kann nicht verarbeitet werden"). Fix: für `package-lock.json`
   gezielt `System.Web.Script.Serialization.JavaScriptSerializer` statt
   `ConvertFrom-Json` — liefert ein `Hashtable`, das mit leeren Keys klarkommt.
   Betrifft NUR die Lockfile-Zählung (package.json selbst hat keine leeren Keys,
   bleibt bei `ConvertFrom-Json`). Wichtig für künftige Sprints, die npm-v3-Lockfiles
   parsen.
3. **Manifest-Parser für pyproject.toml/Cargo.toml/go.mod bewusst als
   Zeilen-Heuristik** (kein voller TOML-Parser) — Simplicity First, konsistent mit
   der Grep-Niveau-Linie aus Sprint 03/04/05. Nur `package.json`/`package-lock.json`
   sind vollständig JSON-basiert robust, da das der Akzeptanz-Zielstack ist.
4. **`time.modified` aus der npm-Registry ist kein reines Publish-Datum**: bei
   `lodash` zeigte der Test ein Datum von HEUTE, obwohl das Paket seit Jahren keine
   neue Version bekommen hat — die Registry aktualisiert `time.modified` auch bei
   reinen Metadaten-Änderungen. In SKILL.md Step 3 als Näherungswert-Hinweis
   dokumentiert, damit der Report das nicht als "Paket wurde heute released"
   missversteht.

## 11. Testergebnisse

**Smoke** (Fixture `skills/deps-erbschaft/tests/fixture/`: `package.json` mit
`lodash` (genutzt in `src/util.ts`) und `left-pad` (ungenutzt)):
`deps-inventory.ps1` liefert `lodash` mit 1 Fundstelle, `left-pad` korrekt in
`unusedDeclared`. `registry-meta.ps1` gegen `lodash` (echte Metadaten: Lizenz MIT,
3 Maintainer) und einen erfundenen Paketnamen (`metaError` mit 404-Meldung, exit 0,
kein Abbruch) getestet — beide Fälle bestanden.

**Akzeptanz** (`dreamzzz-api_vs`, Komplettlauf): 3 direkte Dependencies
(`@cloudflare/workers-types`, `typescript`, `wrangler`, alle `devDependencies`),
91 transitive Pakete laut `package-lock.json`. Alle 3 zeigen `usageCount: 0` im
Quellcode-Scan — aber KEINE echten `unusedDeclared`-Funde: manuell gegen
`tsconfig.json` (`"types": ["@cloudflare/workers-types"]`) und `package.json`
`scripts` (`"dev": "wrangler dev"`, `"deploy": "wrangler deploy"`) sowie
`wrangler.toml` (von der `wrangler`-CLI gelesen) verifiziert — alle 3 sind
Tooling-Dependencies, die nur über Config/CLI genutzt werden, nicht per Import.
Exakt die Config-Nutzungs-Falle aus § 7 der Sprint-Spec, mit einem echten Projekt
bestätigt statt nur theoretisch beschrieben.

**Negativ**: nicht existenter Pfad → `Write-Error` + Exit-Code 1.
