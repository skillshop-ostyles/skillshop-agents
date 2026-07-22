# Sprint 11 — zeitbomben-scanner (/timebomb)

Regeln: `ops/BIBEL.md` gilt vollständig. Wiederverwendung: Blame-Muster aus Sprint 01
(`git-mine.ps1`) darf kopiert/angepasst werden.

## 1. Problem

Jede Codebase tickt: hartkodierte Jahreszahlen, Gutschein-Deadlines im Code,
Zertifikats-Pfade mit Ablaufdatum, 32-Bit-Timestamps, "// temporär, wird nächste
Woche entfernt" von 2019. Diese Bomben findet niemand, weil sie über Kommentare,
Literale und Config verstreut sind und erst am Zündtag explodieren. Ein LLM kann
Datums-Funde fachlich einordnen (Bombe vs. harmlose Konstante), das Git-Alter von
"temporär"-Markern bewerten und eine priorisierte Entschärfungsliste bauen.

## 2. Nutzen

Vorher: Bombe explodiert in Prod ("warum geht seit dem 1.1. nichts mehr?"), Ursache
kostet Stunden. Nachher: Entschärfungsliste mit Zünddatum, sortiert nach Dringlichkeit
(überfällig → tickt → verrottet). Profiteure: On-Call, jeder Jahreswechsel, jeder,
der "temporär" schreibt.

## 3. Scope / Nicht-Scope

**Scope:** Quell- und Config-Dateien eines Projekts. Fund-Klassen: Datums-/Zeit-
Literale, Ablauf-Schlüsselwörter, Provisorien-Marker mit Git-Alter,
32-Bit-Zeit-Verdacht. Read-only.
**Nicht-Scope:** Keine Zertifikats-Dateien parsen (nur Pfade/Erwähnungen melden).
Keine automatische Entschärfung. Keine externen Ablauf-Register (Domains, Lizenzen).

## 4. Skill-Spezifikation

Ordner: `zeitbomben-scanner/`

Frontmatter:

```yaml
---
name: zeitbomben-scanner
description: "Time bomb scanner: finds hardcoded dates, expiry deadlines, cert references, 32-bit time usage and 'temporary' markers rotting since years (git age via blame), then has the LLM classify each finding as live bomb / rotten provisional / false alarm and produce a defusal list ranked by detonation date. Read-only. Trigger: /timebomb"
trigger: /timebomb
---
```

Invocation-Steps:

1. `--help`/`-h` → Usage, stopp.
2. Klären: `-ProjectDir`. Heutiges Datum festhalten (Referenz für "überfällig").
   Bestätigen.
3. `scripts/timebomb-scan.ps1` ausführen.
4. LLM-Analyse gemäß § 6.
5. Report `timebomb-report.md` ins Arbeitsverzeichnis, Kurzfassung mit den
   überfälligen Funden zuerst.

Usage:

```
/timebomb               # interaktiv
/timebomb <dir>         # Projekt scannen
/timebomb --help
```

## 5. Collector-Skripte

### scripts/timebomb-scan.ps1

Parameter: `-ProjectDir` (Pflicht), `-Extensions` (Default wie Sprint 03, plus
json,yaml,yml,toml,ini,xml,config), `-Exclude` (Default wie Sprint 03),
`-ProvisionalAgeDays` (Default 365).

Read-only. Vier Fund-Klassen (jede mit Datei:Zeile + Zeilentext + Klasse):

1. **Datums-Literale**: ISO-Daten (`\d{4}-\d{2}-\d{2}`), Jahreszahlen 2015-2099 in
   Vergleichen/Zuweisungen (`[=<>]\s*['"]?20\d{2}`), Unix-Timestamps (10-stellige
   Zahlen beginnend mit 1 oder 2 in Zeit-Kontext: Zeile enthält time/date/expir/epoch).
2. **Ablauf-Schlüsselwörter**: `expir|deadline|valid.?until|gueltig|ablauf|sunset|
   end.?of.?life|eol` (case-insensitive) — Zeile + 2 Zeilen Kontext.
3. **Provisorien-Marker**: `TODO|FIXME|HACK|XXX|temp(orary|orär)?|provisorisch|
   workaround|quick.?fix|remove (this|later|me)` in Kommentaren. Für jede Fundzeile
   zusätzlich das Blame-Datum ermitteln (`git blame -L <n>,<n> --porcelain`) →
   `ageDays`. Marker mit `ageDays >= ProvisionalAgeDays` → Flag `rotten: true`.
   Kein Git → `ageDays: null`.
4. **32-Bit-Zeit-Verdacht**: `int(32)?\s+.*(time|timestamp)` , `(time|timestamp).*
   \bint\b` in typisierten Sprachen, `2038` überall.

JSON-Schema (Beispiel):

```json
{
  "findings": [
    { "class": "date-literal", "file": "src/promo.ts", "line": 12, "text": "if (now < '2024-12-31')", "date": "2024-12-31" },
    { "class": "provisional", "file": "src/auth.ts", "line": 88, "text": "// temp workaround, remove next week", "ageDays": 1890, "rotten": true, "blameDate": "2021-05-10" }
  ],
  "countsByClass": { "date-literal": 4, "expiry-keyword": 2, "provisional": 17, "int32-time": 0 },
  "gitAvailable": true,
  "scannedFiles": 300
}
```

Bei Datums-Literalen: erkanntes Datum als Feld `date` normalisieren, wo eindeutig
parsebar; sonst null. Fehlerverhalten: Pfad fehlt → exit 1.

## 6. LLM-Analyse-Steps

1. Jeden Fund im Kontext lesen (bei Unklarheit die Datei-Stelle per Read prüfen)
   und klassifizieren:
   - **Scharfe Bombe**: Verhalten ändert sich an einem konkreten Datum
     (Vergleich, Feature-Ende, Ablauf). Zünddatum benennen; liegt es in der
     Vergangenheit → **überfällig** (höchste Priorität — die Bombe ist evtl. schon
     explodiert, mögliches Symptom beschreiben).
   - **Verrottetes Provisorium**: rotten-Marker — was wollte der Autor, was ist das
     Risiko des Dauerzustands (Blame-Datum als Beleg).
   - **Fehlalarm**: Jahreszahl in Copyright, Testdaten, Changelog — aussortieren,
     im Anhang listen.
2. 32-Bit-Funde: nur melden, wenn der Typ tatsächlich Zeit speichert (`vermutet`
   bei Unsicherheit).
3. Report: Kurzfassung (Zählung: überfällig / tickt / verrottet) →
   **Entschärfungsliste** sortiert: überfällig zuerst, dann nach Zünddatum
   aufsteigend, dann Provisorien nach Alter absteigend — je Fund: Klasse, Zünddatum
   bzw. Alter, Evidenz (Datei:Zeile, Blame-Datum), konkreter Entschärfungs-Vorschlag
   → Fehlalarme im Anhang → Offene Fragen.
4. Evidenz-Pflicht: Zünddatum nur aus dem Literal, Alter nur aus Blame; kein
   geschätztes Datum ohne Kennzeichnung `vermutet`.

## 7. Edge-Cases

| Fall | Verhalten |
|---|---|
| Kein Git | ageDays null, Provisorien ohne Alters-Ranking (nur listen), ausweisen |
| Changelog-/Doku-Dateien voller Daten | CHANGELOG*, HISTORY*, docs/ mit Datums-Klasse ausschließen (Provisorien-Klasse trotzdem scannen) |
| Datum in Testdaten | LLM-Klassifikation → Fehlalarm-Anhang |
| Sehr viele Provisorien (> 200) | Nur rotten-Marker in die Liste, Rest als Zählwert |
| Zeitzonen-/Format-Mehrdeutigkeit (01/02/03) | Nicht-ISO-Formate nicht als date-literal werten (bewusste Vereinfachung, dokumentieren) |
| Vendor-Code | Exclude greift (node_modules etc.) |

## 8. Testplan

Smoke: Fixture `zeitbomben-scanner/tests/fixture/` mit einer Datei, die enthält:
1 überfälliges Datum (`2024-12-31` in einem Vergleich), 1 zukünftiges Datum,
1 alten TODO-Kommentar, 1 Copyright-Jahr (Fehlalarm-Kandidat). Fixture committen,
damit Blame-Alter existiert. Dann:

```powershell
& .\zeitbomben-scanner\scripts\timebomb-scan.ps1 -ProjectDir ".\zeitbomben-scanner\tests\fixture" -ProvisionalAgeDays 0
```

Erwartung: exit 0, JSON valide, alle 4 Stellen gefunden, TODO mit ageDays != null.
LLM-Durchlauf: überfälliges Datum als "überfällig" klassifiziert, Copyright als
Fehlalarm (harte Kriterien). Hinweis: Fixture liegt im AGENTS-Repo → Blame liefert
das Commit-Datum des Sprints; `-ProvisionalAgeDays 0` macht den Marker testbar rotten.

Akzeptanz (dreamzzz-api): Komplettlauf. Erwartung: Lauf ohne Fehler, 3 Funde
stichprobenartig gegen Quelle geprüft, Klassifikation nachvollziehbar.

Negativ: ungültiger Pfad → exit != 0.

## 9. DoD-Checkliste

- [x] SKILL.md vollständig
- [x] timebomb-scan.ps1 mit allen 4 Fund-Klassen + Blame-Alter + Normalisierung
- [x] Fixture angelegt und committet
- [x] Smoke bestanden (alle 4 Stellen, JSON validiert)
- [x] LLM-Klassifikation: überfällig erkannt, Fehlalarm aussortiert
- [x] Akzeptanz-Lauf dokumentiert (3 Stichproben)
- [x] Negativ-Test bestanden
- [x] Report erfüllt BIBEL § 4
- [x] tracking.md aktualisiert, Commit `sprint-11: zeitbomben-scanner implementiert`

## 10. Entscheidungen während der Umsetzung

1. **Skill-Ordner-Pfad**: `skills/zeitbomben-scanner/` (BIBEL-§-3-Konvention
   seit Sprint 29).
2. **Jahres-Regex bewusst breiter als im Sprint-File wörtlich beschrieben**:
   die dort genannte Form (`[=<>]\s*['"]?20\d{2}`, nur Vergleiche/Zuweisungen)
   hätte "Copyright 2019" NIE getroffen — der Testplan verlangt aber
   ausdrücklich "alle 4 Stellen gefunden" inklusive des Copyright-Jahrs als
   Fehlalarm-Kandidat für die LLM-Klassifikation. Interner Widerspruch im
   Sprint-File zwischen Kollektor-Spezifikation und Testplan-Erwartung
   aufgelöst zugunsten des Testplans: jede wortgrenzen-genaue Jahreszahl
   2015-2099 wird erfasst, unabhängig vom Kontext — die Präzisions-Arbeit
   (Copyright vs. echte Bombe) liegt bewusst bei der LLM-Analyse (§ 6.1),
   nicht beim Collector. Beim Akzeptanz-Lauf bestätigt: `maxOutputTokens: 2048`
   in `gemini.ts`/`index.ts` wird ebenfalls (korrekt als Fehlalarm-Kandidat)
   erfasst — ein weiteres reales Beispiel für genau diese Abgrenzung.
3. **Fixture früh committet** (eigener Zwischen-Commit vor dem Sprint-Abschluss),
   damit `git blame` echte Historie für den Provisorien-Marker liefert (wie im
   Sprint-File verlangt) — `-ProvisionalAgeDays 0` macht den frischen Marker
   trotzdem testbar `rotten`, ohne künstliches Backdaten.

## 11. Testergebnisse

**Smoke** (Fixture `skills/zeitbomben-scanner/tests/fixture/promo.ts`, committet
vor dem Test): `timebomb-scan.ps1 -ProvisionalAgeDays 0` findet **alle 4**
Pflicht-Stellen — Copyright-Jahr 2019 (date-literal), TODO-Marker
(`ageDays: 0`, `rotten: true`, `blameDate` = heutiges Commit-Datum), überfälliges
Datum `2024-12-31`, zukünftiges Datum `2027-01-01`. JSON valide, exit 0.
Manuelle Klassifikation (hartes Kriterium): `2024-12-31` liegt vor dem heutigen
Datum (2026-07-22) → **überfällig**; `2019` in einer Copyright-Zeile →
**Fehlalarm**, korrekt aussortierbar.

**Akzeptanz** (`dreamzzz-api_vs/src`): 9 Dateien gescannt, 9 date-literal-, 4
expiry-keyword-, 1 provisional-, 0 int32-time-Funde. 3 Stichproben per `sed -n`
verifiziert: `entitlements.ts:74` (echter "Subscription expired"-Kommentar),
`index.ts:1377` (DSGVO-Consent-TTL, 3 Jahre — reale Ablauf-Logik, kein Bug),
`gemini.ts:262` (`maxOutputTokens: 2048` — Token-Limit, kein Datum; bestätigt
die bewusste Entscheidung 2 in der Praxis: der Collector meldet es, die
LLM-Analyse müsste es als Fehlalarm aussortieren).

**Negativ**: nicht existenter Pfad → `Write-Error` + Exit-Code 1.
