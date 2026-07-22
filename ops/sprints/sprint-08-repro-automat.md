# Sprint 08 — repro-automat (/repro)

Regeln: `ops/BIBEL.md` gilt vollständig.

## 1. Problem

"Geht nicht" — der teuerste Satz der Branche. Zwischen vagem Bug-Report und
verwertbarem Repro liegen Stunden Detektivarbeit: Umgebung erraten, Eingaben
rekonstruieren, Zustand nachbauen. Die meisten Bugs sterben nicht am Fix, sondern an
der Reproduktion. Ein LLM kann aus Report-Text Hypothesen extrahieren, gezielt
Repro-Kandidaten generieren, sie AUSFÜHREN und anhand des Ergebnisses iterieren —
eine Suchschleife, die vorher nur ein erfahrener Mensch fahren konnte.

## 2. Nutzen

Vorher: 1-4 Stunden bis zum Repro, oft "cannot reproduce" als Endstation. Nachher:
entweder ein minimaler, ausführbarer Repro-Test (der nachweislich fehlschlägt) oder
eine präzise Liste, welche Information zum Reproduzieren fehlt — beides in Minuten
statt Stunden. Profiteure: Bug-Bearbeiter, Support (bekommt konkrete Rückfragen),
QA (Repro wird Regressionstest).

## 3. Scope / Nicht-Scope

**Scope:** Input = Bug-Report als Freitext (+ optional Stacktrace/Logs) + Zielprojekt.
Output = Repro-Artefakt (Test-Datei oder Standalone-Skript) im ARBEITSVERZEICHNIS
(nicht im Zielprojekt) + Repro-Protokoll. Iterationsschleife max. 5 Versuche.
**Nicht-Scope:** Kein Fix (Repro ist das Produkt; Fix ist ein Folgeauftrag). Keine
UI-/Browser-Reproduktion (nur Code-Ebene: Funktionen, API-Aufrufe, CLI). Keine
Produktions-Datenbanken anfassen — Repro läuft nur mit lokalen/synthetischen Daten.

## 4. Skill-Spezifikation

Ordner: `repro-automat/`

Frontmatter:

```yaml
---
name: repro-automat
description: "Turns a vague bug report into a minimal, runnable reproduction: extracts hypotheses from the report text, snapshots the environment, generates a repro test/script, EXECUTES it and iterates (max 5 attempts) until the bug demonstrably reproduces - or documents precisely which information is missing. The repro lives outside the target project. Trigger: /repro"
trigger: /repro
---
```

Invocation-Steps:

1. `--help` → Usage, stopp.
2. Klären: `-ProjectDir` + Bug-Report (Freitext einfügen lassen oder Datei-Pfad).
   Bestätigen.
3. `scripts/env-snapshot.ps1` ausführen.
4. Hypothesen-Extraktion + Repro-Schleife gemäß § 6.
5. Ergebnis: `repro/`-Ordner im Arbeitsverzeichnis mit Repro-Artefakt +
   `repro-protokoll.md`. Kurz-Zusammenfassung: reproduziert ja/nein, wie, was fehlt.

Usage:

```
/repro                          # interaktiv
/repro <repo>                   # Report wird abgefragt
/repro <repo> <report-datei>    # Report aus Datei
/repro --help
```

## 5. Collector-Skripte

### scripts/env-snapshot.ps1

Parameter: `-ProjectDir` (Pflicht).

Read-only. Sammelt, was für Repro-Treue zählt:

1. **Stack & Versionen**: erkennt Stack (Muster elevate/audit.ps1), liest Runtime-
   Versionen (node --version, python --version, dotnet --version, go version —
   nur die zum Stack passenden; fehlende Runtimes → Feld null, kein Abbruch).
2. **Projekt-Metadaten**: Framework + Test-Runner aus Manifest (z. B. vitest/jest/
   pytest erkennbar), vorhandene Test-Skripte (`package.json scripts.test` etc.).
3. **Git-Zustand**: aktueller Branch + HEAD-Hash + dirty ja/nein (Repro-Protokoll
   muss festhalten, GEGEN welchen Stand reproduziert wurde).
4. **Entry-Points**: Kandidaten (main/index/app) als Orientierung.

JSON-Schema (Beispiel):

```json
{
  "stack": "node-ts",
  "runtimes": { "node": "v20.11.0" },
  "testRunner": "vitest",
  "testCommand": "npm test",
  "git": { "branch": "main", "head": "abc123", "dirty": false },
  "entryPoints": ["src/index.ts"]
}
```

Fehlerverhalten: Pfad fehlt → exit 1. Alles andere best effort mit null-Feldern.

## 6. LLM-Analyse-Steps (Repro-Schleife)

1. **Report sezieren**: Symptom (was passiert), Erwartung (was sollte passieren),
   Auslöser-Kandidaten (Eingaben, Reihenfolge, Zustand), Umgebungs-Hinweise.
   Fehlende Kern-Angaben SOFORT als "fehlende Infos" notieren, aber trotzdem mit
   Hypothesen weitermachen (nicht vorschnell aufgeben).
2. **Verdächtigen Code lokalisieren**: aus Symptom-Begriffen + Stacktrace (falls
   vorhanden) die relevanten Dateien finden und LESEN (Grep + Read). Hypothesen
   bilden: unter welchen Bedingungen erzeugt dieser Code das Symptom? Hypothesen
   nach Wahrscheinlichkeit ordnen.
3. **Repro-Artefakt generieren** (im Arbeitsverzeichnis-`repro/`, NIE im Zielprojekt):
   bevorzugt ein Test im Stil des vorhandenen Test-Runners, der das Zielprojekt
   importiert/aufruft; sonst Standalone-Skript. Minimal: ein Szenario, harte
   Assertion auf das ERWARTETE Verhalten (der Test MUSS beim Vorliegen des Bugs rot
   sein — das ist die Beweis-Logik).
4. **Ausführen** (Bash/PowerShell), Ergebnis interpretieren:
   - Assertion schlägt fehl mit dem berichteten Symptom → **reproduziert**. Artefakt
     minimieren (Unnötiges entfernen, nochmal laufen lassen — muss rot bleiben).
   - Test grün oder anderes Symptom → Hypothese verwerfen/verfeinern, nächster
     Versuch. **Max. 5 Versuche**, jeden im Protokoll festhalten (Hypothese,
     Artefakt-Version, Ergebnis).
5. **Abschluss**:
   - Reproduziert: `repro-protokoll.md` mit Umgebungs-Snapshot, finalem Artefakt,
     exakter Ausgabe des roten Laufs, Einordnung (welche Hypothese traf zu, `belegt`
     durch Lauf-Output). Hinweis: Artefakt eignet sich als Regressionstest.
   - Nicht reproduziert: Protokoll mit allen 5 Versuchen + präzise Liste fehlender
     Infos als kopierfertige Rückfragen an den Melder ("Welche Locale?", "Welche
     Datenmenge?"). KEIN "cannot reproduce" ohne diese Liste.
6. Evidenz-Pflicht: "reproduziert" nur mit wörtlicher Fehlerausgabe des Laufs im
   Protokoll. Hypothesen ohne Lauf sind maximal `vermutet`.

## 7. Edge-Cases

| Fall | Verhalten |
|---|---|
| Report ohne jede verwertbare Angabe | 1 Hypothesen-Versuch aus Code-Lektüre, dann früh abbrechen mit Rückfragen-Liste (nicht 5 Blind-Versuche verbrennen) |
| Bug braucht externe Services (DB, API) | Mit Stubs/Fakes im Repro-Artefakt arbeiten; wenn unmöglich: als fehlende Info dokumentieren |
| Test-Runner-Installation fehlt im Zielprojekt | Standalone-Skript statt Test; nichts im Zielprojekt installieren |
| Repro braucht Dependency-Installation im repro/-Ordner | Erlaubt (eigener Ordner), im Protokoll dokumentieren |
| Bug ist ein Heisenbug (Timing/Race) | Artefakt mit Wiederholungsschleife (N Läufe, Fehlerquote messen); "reproduziert" ab nachweisbarer Quote, Quote im Protokoll |
| Zielprojekt-Tests selbst kaputt | Irrelevant — Repro läuft isoliert; nur erwähnen |
| dirty Working Tree im Zielprojekt | Im Protokoll ausweisen (Repro gilt für diesen Zustand) |

## 8. Testplan

Smoke: Fixture `repro-automat/tests/fixture/` = Mini-Node-Projekt (package.json +
eine Datei mit ABSICHTLICHEM Bug, z. B. Off-by-one in einer Datumsfunktion) + ein
Beispiel-Bug-Report `bug-report.md` ("Rechnung vom Monatsletzten landet im
Folgemonat"). Dann:

```powershell
& .\repro-automat\scripts\env-snapshot.ps1 -ProjectDir ".\repro-automat\tests\fixture"
```

Erwartung: exit 0, JSON valide, Stack erkannt. Voller Skill-Durchlauf gegen die
Fixture: der eingebaute Bug MUSS innerhalb der 5 Versuche reproduziert werden
(hartes Akzeptanzkriterium), Protokoll vollständig.

Akzeptanz (dreamzzz-api): env-snapshot ausführen (Erwartung: Stack/Versionen korrekt).
Voller Repro-Lauf nur, falls ein echter Bug-Report vorliegt — sonst dokumentieren:
"Akzeptanz auf Fixture erbracht, dreamzzz nur Snapshot" (zulässig, da der Kern —
die Schleife — an der Fixture bewiesen ist).

Negativ: ungültiger Pfad → exit != 0.

## 9. DoD-Checkliste

- [x] SKILL.md vollständig inkl. 5-Versuche-Limit und repro/-Isolation
- [x] env-snapshot.ps1 gemäß Spezifikation
- [x] Fixture mit eingebautem Bug + Beispiel-Report angelegt
- [x] Smoke bestanden; Fixture-Bug innerhalb 5 Versuchen reproduziert, Protokoll vollständig
- [x] Akzeptanz dokumentiert (mind. Snapshot gegen dreamzzz)
- [x] Negativ-Test bestanden
- [x] Protokoll erfüllt § 6.6 (Evidenz = wörtlicher Lauf-Output)
- [x] tracking.md aktualisiert, Commit `sprint-08: repro-automat implementiert`

## 10. Entscheidungen während der Umsetzung

1. **Skill-Ordner-Pfad**: `skills/repro-automat/` (BIBEL-§-3-Konvention seit
   Sprint 29).
2. **Fixture-Bug**: klassische JavaScript-`Date.setMonth()`-Falle (Tag-Überlauf
   normalisiert monatsübergreifend statt auf den Monatsletzten zu clampen) —
   real, bekannt, deterministisch reproduzierbar, exakt passend zum
   Beispiel-Symptom "Rechnung vom Monatsletzten landet im Folgemonat".
3. **Repro-Artefakt für den Sprint-Nachweis im Scratchpad erzeugt** (nicht im
   Skill-Ordner committet) — genau wie SKILL.md Step 5/6 vorschreiben: Repro-
   Artefakte gehören ins Arbeitsverzeichnis des jeweiligen Aufrufs, niemals als
   Dauerzustand ins Repo. Das Sprint-File hier dokumentiert den Lauf-Output als
   Beleg, das Artefakt selbst ist Wegwerf-Ware.

## 11. Testergebnisse

**Smoke**: `env-snapshot.ps1` gegen die Fixture erkennt Stack `node-ts`, Node
v24.12.0, Git-Zustand korrekt (läuft innerhalb des AGENTS-Repos). Voller
Skill-Durchlauf gegen die Fixture (Bug-Report `bug-report.md`, Zielfunktion
`nextBillingDate` in `billing.js`): Hypothese aus Code-Lektüre (`Date.setMonth()`
normalisiert Tag-Überlauf monatsübergreifend) — **reproduziert im 1. von max. 5
Versuchen**:

```
nextBillingDate('2024-01-31') = 2024-03-02
FEHLGESCHLAGEN: erwartet ein Datum im Februar (2024-02-*), erhalten: 2024-03-02
```

Exit-Code 1, exakt das gemeldete Symptom (Datum landet im Folgemonat — hier sogar
übernächsten). Repro-Protokoll mit Umgebungs-Snapshot, Hypothese, Artefakt,
wörtlichem Lauf-Output und Einordnung erstellt — erfüllt § 6.6 (Evidenz =
wörtlicher Lauf-Output, keine Behauptung ohne Beleg).

**Akzeptanz** (`dreamzzz-api_vs`): `env-snapshot.ps1` korrekt: Stack `node-ts`,
Node v24.12.0, Git-Zustand (Branch/Head/dirty), Entry-Point `src/index.ts`
gefunden. Kein echter Bug-Report für dreamzzz-api_vs vorhanden — Akzeptanz auf
Snapshot-Ebene erbracht, wie im Sprint-File als zulässig vorgesehen (die
Kern-Schleife ist an der Fixture bewiesen).

**Negativ**: nicht existenter Pfad → `Write-Error` + Exit-Code 1.
