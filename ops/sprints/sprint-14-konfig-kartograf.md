# Sprint 14 — konfig-kartograf (/config-map)

Regeln: `ops/BIBEL.md` gilt vollständig. Secrets-Regel (§ 2.5) ist hier ZENTRAL:
Werte werden grundsätzlich nie ausgegeben, nur Schlüsselnamen.

## 1. Problem

Konfiguration wuchert: Env-Vars, Settings-Dateien, Feature-Flags, Defaults im Code —
verteilt über .env-Beispiele, YAML, JSON, Deployment-Skripte und `process.env`-Zugriffe.
Niemand kennt die vollständige Konfigurations-Oberfläche eines Systems: Welche
Schlüssel gibt es? Wo werden sie gelesen? Welche sind verwaist, welche werden gelesen,
aber nirgends definiert (der klassische Prod-Crash beim Deployment)? Diese Landkarte
manuell zu bauen ist tagelange Suchfleißarbeit — für ein LLM mit gutem Collector ein
systematischer Abgleich.

## 2. Nutzen

Vorher: "Welche Env-Vars braucht das System?" beantwortet niemand vollständig;
fehlende Vars fallen erst beim Start in Prod auf. Nachher: Konfig-Landkarte
(Schlüssel × definiert-in × gelesen-in), Befunde: gelesen-nie-definiert (Crash-Kandidat),
definiert-nie-gelesen (verwaist), divergente Defaults. Profiteure: DevOps
(Deployments), Onboarding, jeder "warum startet es bei mir nicht"-Fall.

## 3. Scope / Nicht-Scope

**Scope:** Definitionsquellen (.env*, appsettings*.json, config/*.{json,yaml,yml,toml},
docker-compose*.yml environment-Blöcke, Dockerfile ENV) + Lese-Stellen im Code
(process.env, os.environ/getenv, IConfiguration, viper/env-Libs — Muster-Familie).
Abgleich + Landkarte.
**Nicht-Scope:** KEINE Werte ausgeben — nur Schlüssel; Werte aus .env-Dateien werden
vom Collector verworfen (nur `hasValue: true/false`). Keine Remote-Config-Systeme
(Vault, SSM — nur deren Erwähnung melden). Keine Config-Änderungen.

## 4. Skill-Spezifikation

Ordner: `konfig-kartograf/`

Frontmatter:

```yaml
---
name: konfig-kartograf
description: "Configuration cartographer: maps a system's complete config surface - every env var, setting and flag, where it is defined (.env, yaml/json configs, compose, Dockerfile) versus where it is read in code - and reports read-but-never-defined keys (crash candidates), defined-but-never-read orphans and divergent defaults. Never outputs values, keys only. Read-only. Trigger: /config-map"
trigger: /config-map
---
```

Invocation-Steps:

1. `--help`/`-h` → Usage, stopp.
2. Klären: `-ProjectDir`. Bestätigen.
3. `scripts/config-harvest.ps1` ausführen.
4. LLM-Analyse gemäß § 6.
5. Report `config-map-report.md` ins Arbeitsverzeichnis; Kurzfassung: Crash-Kandidaten
   zuerst.

Usage:

```
/config-map               # interaktiv
/config-map <dir>         # Konfig-Landkarte erstellen
/config-map --help
```

## 5. Collector-Skripte

### scripts/config-harvest.ps1

Parameter: `-ProjectDir` (Pflicht), `-Extensions`/`-Exclude` (Defaults wie Sprint 03).

Read-only. Zwei Sammel-Richtungen:

1. **Definitionen** — pro Quelle Schlüssel extrahieren (NIE Werte; nur
   `hasValue`-Flag und bei Nicht-Secret-Quellen den Default-Typ grob:
   number/bool/string/empty):
   - `.env`, `.env.*`, `*.env.example`: Zeilen `KEY=...`.
   - `appsettings*.json`, `config/**/*.{json,yaml,yml,toml}`: Schlüsselpfade
     flach geklopft (`Logging.LogLevel.Default`).
   - `docker-compose*.yml`: `environment:`-Einträge.
   - `Dockerfile*`: `ENV KEY ...`.
   Sonderregel Secrets: bei Dateien mit `.env`-Charakter wird zusätzlich zum
   Verwerfen der Werte geprüft, ob der Schlüsselname secret-artig ist
   (`SECRET|TOKEN|KEY|PASSWORD|PWD|CREDENTIAL`) → Flag `sensitive: true`.
2. **Lese-Stellen** im Code (Datei:Zeile + extrahierter Schlüssel):
   - `process.env.KEY` / `process.env["KEY"]` / destrukturiert `{ KEY } = process.env`.
   - `os.environ["KEY"]` / `os.getenv("KEY")` / `env::var("KEY")` /
     `os.Getenv("KEY")` / `System.getenv("KEY")`.
   - `IConfiguration["A:B"]` / `.GetSection("A")` / `builder.Configuration[...]`.
   - Generisch: `getenv|env\(|config\.get\(` mit String-Literal-Argument.
   Zugriffe mit dynamischem Schlüssel (Variable statt Literal) → Liste
   `dynamicReads` (Datei:Zeile) — Abdeckungslücke, die der Report ausweisen muss.

JSON-Schema (Beispiel):

```json
{
  "definitions": [
    { "key": "DATABASE_URL", "source": ".env.example", "line": 3, "hasValue": true, "sensitive": true, "defaultType": null }
  ],
  "reads": [
    { "key": "DATABASE_URL", "file": "src/db.ts", "line": 8, "pattern": "process.env" }
  ],
  "dynamicReads": [ { "file": "src/plugin-loader.ts", "line": 44 } ],
  "counts": { "definitions": 24, "reads": 31, "distinctKeys": 27 }
}
```

Fehlerverhalten: Pfad fehlt → exit 1. Keine Definitionsquellen gefunden → leere
Liste, exit 0 (Abgleich läuft dann einseitig, Report weist es aus).

## 6. LLM-Analyse-Steps

1. **Schlüssel-Normalisierung**: gelesene und definierte Schlüssel matchen —
   exakt, dann case-insensitive, dann Pfad-Varianten (`A:B` vs `A__B` vs `A.B` —
   .NET/Docker-Konventionen). Unsichere Matches als `wahrscheinlich` kennzeichnen.
2. **Befund-Klassen** bilden:
   - **Gelesen, nie definiert** (Crash-/Fehlkonfigurations-Kandidat — Severity hoch;
     prüfen, ob im Code ein Fallback existiert: `?? default`, `getenv(..., default)` —
     mit Fallback nur mittel).
   - **Definiert, nie gelesen** (verwaist — es sei denn, es ist ein bekannter
     Runtime-Schlüssel: NODE_ENV, ASPNETCORE_*, PATH etc. — Whitelist anwenden,
     aussortierte listen).
   - **Mehrfach definiert mit Konflikt-Potenzial** (gleicher Schlüssel in mehreren
     Quellen — Präzedenz unklar; Quellen nennen).
   - **Sensitiv ohne Beispiel-Eintrag** (sensitive-Schlüssel, der in keiner
     *.example-Datei dokumentiert ist — Onboarding-Falle).
3. **Landkarte** bauen: Tabelle Schlüssel × definiert-in × gelesen-in (Datei:Zeile),
   sensitiv-Spalte.
4. Report: Kurzfassung (Kennzahlen + Crash-Kandidaten) → Befunde nach Klasse mit
   Evidenz → Landkarten-Tabelle → dynamicReads-Abdeckungslücke → Offene Fragen.
5. Evidenz-Pflicht: jeder Befund mit beiden Seiten (Lese-Stelle UND
   Definitions-Fundort bzw. dokumentierte Fehlanzeige der Suche). Werte tauchen
   NIRGENDS auf.

## 7. Edge-Cases

| Fall | Verhalten |
|---|---|
| .env im .gitignore, nur .env.example da | Normalfall — example ist die Doku-Quelle; echtes .env NICHT lesen (nur Existenz melden) |
| dynamische Schlüssel (Loops, Präfix-Scans) | dynamicReads, als Lücke ausweisen, keine Erfindungen |
| Vault/SSM/K8s-Secrets-Referenzen | Erwähnung melden ("externe Quelle X im Spiel"), nicht auflösen |
| Monorepo mit mehreren .env | Pro Teilprojekt gruppieren (Quell-Pfad zeigt Zugehörigkeit) |
| Config-Schlüssel in Tests definiert | Als Quelle `test` markieren, nicht als Prod-Definition werten |
| Kommentierte Zeilen in .env (# KEY=) | Als `commented: true` erfassen — oft die halbe Doku |

## 8. Testplan

Smoke: Fixture `konfig-kartograf/tests/fixture/` mit: `.env.example`
(3 Schlüssel, davon 1 sensitiv, 1 nirgends gelesen), 1 Quelldatei (liest 2 davon
plus 1 NIRGENDS definierten Schlüssel, einer mit `?? 'fallback'`). Dann:

```powershell
& .\konfig-kartograf\scripts\config-harvest.ps1 -ProjectDir ".\konfig-kartograf\tests\fixture"
```

Erwartung: exit 0, JSON valide, alle Definitionen/Reads korrekt, KEIN Wert im
Output (mit Grep über die JSON-Ausgabe verifizieren: der bekannte Fixture-Wert darf
nicht vorkommen — hartes Kriterium). LLM-Durchlauf: gelesen-nie-definiert gefunden
(mit Fallback-Herabstufung), verwaister Schlüssel gefunden, sensitiv korrekt markiert.

Akzeptanz (dreamzzz-api): Komplettlauf. Erwartung: Landkarte plausibel, 3 Befunde
stichprobenartig verifiziert, kein Wert im Report (Grep-Kontrolle).

Negativ: ungültiger Pfad → exit != 0.

## 9. DoD-Checkliste

- [ ] SKILL.md vollständig (Werte-Verbot prominent)
- [ ] config-harvest.ps1 (alle Definitionsquellen, Lese-Muster, dynamicReads, sensitive-Flag)
- [ ] Fixture angelegt
- [ ] Smoke bestanden inkl. Werte-Verbots-Grep
- [ ] LLM-Befunde: alle 3 eingebauten Fälle korrekt
- [ ] Akzeptanz-Lauf dokumentiert (3 Stichproben + Werte-Grep)
- [ ] Negativ-Test bestanden
- [ ] Report erfüllt BIBEL § 4
- [ ] tracking.md aktualisiert, Commit `sprint-14: konfig-kartograf implementiert`
