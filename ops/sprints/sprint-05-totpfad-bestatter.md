# Sprint 05 — totpfad-bestatter (/bury)

Regeln: `ops/BIBEL.md` gilt vollständig. Wiederverwendung: Scan-Muster aus Sprint 03/04
(ref-scan) darf kopiert/angepasst werden.

## 1. Problem

Jede gewachsene Codebase schleppt tote Pfade mit: nie aufgerufene Funktionen,
Feature-Flags, die seit Jahren aus sind, Dateien, die nur noch von anderen toten
Dateien referenziert werden. Niemand löscht sie, weil niemand BEWEISEN kann, dass sie
tot sind — die Angst vor dem einen versteckten Aufruf gewinnt immer. Ein LLM kann
statische Nichterreichbarkeit, Laufzeit-Evidenz (Coverage, Logs) und Git-Historie
("seit 4 Jahren unangetastet") zu einem belastbaren Todesurteil pro Kandidat
verdichten — inklusive ehrlicher Restrisiko-Angabe.

## 2. Nutzen

Vorher: toter Code wächst monoton, jeder Reader zahlt den Verständnis-Preis. Nachher:
priorisierte Bestattungsliste mit Evidenz-Stärke je Kandidat und vorbereiteten
Lösch-Patches, die der User einzeln freigibt. Profiteure: alle Leser der Codebase,
Security (weniger Angriffsfläche), Build-Zeiten.

## 3. Scope / Nicht-Scope

**Scope:** Statische Unerreichbarkeit (unreferenzierte Exporte/Dateien) + optionale
Laufzeit-Evidenz (Coverage-Reports, Log-Dateien, wenn vorhanden) + Alters-Evidenz
(git log). Vorbereitung von Lösch-Patches.
**Nicht-Scope:** NIEMALS automatisch löschen. Kein dynamisches Tracing/Profiling.
Reflection-/DI-/Konventions-Aufrufe (Routen, Event-Handler) werden nicht sicher
erkannt — das ist die zentrale Restrisiko-Kategorie und wird immer ausgewiesen.

## 4. Skill-Spezifikation

Ordner: `totpfad-bestatter/`

Frontmatter:

```yaml
---
name: totpfad-bestatter
description: "Dead-path undertaker: identifies provably unreachable code by combining static reachability (unreferenced exports/files), optional runtime evidence (coverage reports, logs) and git age, then produces a burial list ranked by evidence strength. NEVER deletes automatically - prepares patches for individual user approval only. Trigger: /bury"
trigger: /bury
---
```

Invocation-Steps:

1. `--help` → Usage, stopp.
2. Klären: `-ProjectDir`; optional Pfade zu Coverage-Report (lcov/cobertura/
   coverage-summary.json) und/oder Log-Dateien. Bestätigen.
3. `scripts/reachability.ps1` ausführen.
4. Falls Coverage/Logs angegeben: `scripts/evidence.ps1` ausführen.
5. Alters-Daten: pro Kandidat `git log -1 --format=%ci -- <datei>` (im SKILL.md-Step
   per Bash/PowerShell, kein eigenes Skript nötig — Simplicity First).
6. LLM-Analyse gemäß § 6, Report `bury-report.md`.
7. NUR auf explizite Einzel-Freigabe des Users: Lösch-Patch für den freigegebenen
   Kandidaten erstellen (Edit im Zielprojekt erst nach Freigabe; vorher als
   Diff-Vorschau im Report).

Usage:

```
/bury                                # interaktiv
/bury <dir>                          # nur statisch + git-Alter
/bury <dir> -coverage <report>       # plus Coverage-Evidenz
/bury <dir> -logs <logdir>           # plus Log-Evidenz
/bury --help
```

## 5. Collector-Skripte

### scripts/reachability.ps1

Parameter: `-ProjectDir` (Pflicht), `-Extensions`/`-Exclude` (Defaults wie Sprint 03).

Read-only. Zweistufig:

1. **Export-Inventar**: pro Quelldatei exportierte/öffentliche Symbole per Muster
   (`export (function|const|class|interface) <name>`, `public .* <name>(`, `def <name>`,
   `func <name>` — sprachfamilienweise, best effort).
2. **Referenz-Zählung**: pro Symbol Vorkommen in ANDEREN Dateien (Wortgrenze).
   0 externe Referenzen → Kandidat. Zusätzlich Datei-Ebene: Dateien, die von keiner
   anderen Datei importiert/referenziert werden (Dateiname ohne Endung als Suchbegriff)
   und keine bekannten Entry-Points sind (index.*, main.*, app.*, program.*,
   *.test.*, *.spec.*, *.config.* — Liste als Parameter überschreibbar).

JSON-Schema (Beispiel):

```json
{
  "symbolCandidates": [
    { "file": "src/legacy/exporter.ts", "line": 12, "symbol": "exportToXml", "externalRefs": 0 }
  ],
  "fileCandidates": [
    { "file": "src/legacy/old-mapper.ts", "referencedBy": 0, "isEntryPointPattern": false }
  ],
  "scannedFiles": 300
}
```

### scripts/evidence.ps1

Parameter: `-ProjectDir` (Pflicht), `-CoverageFile` (optional), `-LogDir` (optional),
`-Candidates` (Pflicht: Pfad zur JSON-Ausgabe von reachability.ps1).

Read-only. Reichert Kandidaten an:
- Coverage: unterstützt `coverage-summary.json` (istanbul) und lcov.info — pro
  Kandidaten-Datei: covered lines / total (0 covered = starke Todes-Evidenz).
  Unbekanntes Format → Meldung, Feld `coverage: null`.
- Logs: Symbolname-Grep über Log-Dateien (Kandidaten, deren Name in Logs auftaucht,
  sind NICHT tot — starke Lebens-Evidenz, Kandidat entfernen bzw. markieren).

JSON: Kandidatenliste aus Input + Felder `coverage` und `logHits` je Kandidat.

Fehlerverhalten beider Skripte: fehlende Pflicht-Pfade → exit 1; fehlende optionale
Quellen → Felder null, exit 0.

## 6. LLM-Analyse-Steps

1. Kandidaten plausibilisieren: bekannte False-Positive-Klassen aktiv prüfen und
   AUSSORTIEREN oder herabstufen — Framework-Konventionen (Routen-Handler,
   Lifecycle-Methoden, DI-Registrierungen, Reflection-Strings, dynamische Importe,
   öffentliche Paket-API bei Libraries). Jede Aussortierung begründen.
2. Evidenz-Stärke je verbleibendem Kandidat:
   - **Stark**: 0 Referenzen + 0 Coverage + keine Log-Treffer + > 2 Jahre unberührt.
   - **Mittel**: 0 Referenzen + (Coverage ODER Alter), keine Laufzeit-Daten dagegen.
   - **Schwach**: nur statisch, junge Datei oder keine Laufzeit-Daten vorhanden.
3. Report: Kurzfassung (X Kandidaten: stark/mittel/schwach) → Bestattungsliste
   sortiert nach Stärke, je Kandidat: alle Evidenz (Refs, Coverage, Logs, letzter
   Commit + Hash), Restrisiko-Hinweis (welche dynamische Aufrufart NICHT
   ausgeschlossen werden konnte), Diff-Vorschau der Löschung → Aussortierte mit
   Begründung → Offene Fragen.
4. Danach den User fragen, welche Kandidaten (einzeln, per Nummer) bestattet werden
   sollen. Nur freigegebene löschen; danach dem User empfehlen, Build+Tests des
   Zielprojekts laufen zu lassen. Keine Freigabe → Ende beim Report.
5. Evidenz-Pflicht: kein Kandidat ohne vollständige Evidenz-Zeile.

## 7. Edge-Cases

| Fall | Verhalten |
|---|---|
| Library-Projekt (Exporte SIND die API) | Erkennen (package.json main/exports, pyproject) → Symbol-Kandidaten nur `schwach`, deutlicher Hinweis |
| Kein Coverage/Logs vorhanden | Normal weiter, alles max. `mittel`, Lücke ausweisen |
| Coverage-Format unbekannt | Meldung, coverage: null, kein Abbruch |
| Kein Git | Alters-Evidenz entfällt, ausweisen |
| Sehr generischer Symbolname | Referenz-Zählung unzuverlässig (Treffer ≠ Nutzung) — LLM prüft Trefferkontext, sonst herabstufen |
| dist/build im Repo | Exclude greift; niemals generierte Artefakte als Kandidaten melden |

## 8. Testplan

Smoke: Fixture `totpfad-bestatter/tests/fixture/` mit 3 Mini-Dateien: A exportiert
`usedFn` (von B genutzt) und `deadFn` (nirgends genutzt); C wird von niemandem
referenziert. Dann:

```powershell
& .\totpfad-bestatter\scripts\reachability.ps1 -ProjectDir ".\totpfad-bestatter\tests\fixture"
```

Erwartung: `deadFn` als Symbol-Kandidat, C als Datei-Kandidat, `usedFn` NICHT
gemeldet (hartes Kriterium: keine False Positives in der Fixture). evidence.ps1 mit
einer Mini-lcov-Datei testen (deadFn: 0 covered).

Akzeptanz (dreamzzz-api): Lauf nur statisch + git-Alter. Erwartung: Lauf ohne
Fehler; 3 gemeldete Kandidaten manuell gegenprüfen (Grep über das Projekt — wirklich
0 externe Referenzen?). KEINE Löschung im Akzeptanz-Lauf (Fremdprojekt bleibt
unberührt, BIBEL § 2.6).

Negativ: ungültiger Pfad → exit != 0; Löschversuch ohne Einzel-Freigabe darf im
SKILL.md-Ablauf nicht vorkommen (Review des SKILL.md-Texts gegen § 6.4).

## 9. DoD-Checkliste

- [x] SKILL.md vollständig, Lösch-Ablauf NUR nach Einzel-Freigabe formuliert
- [x] reachability.ps1 + evidence.ps1 gemäß Spezifikation
- [x] Fixture angelegt; Smoke bestanden ohne False Positives
- [x] Akzeptanz-Lauf dokumentiert (3 Kandidaten manuell verifiziert, nichts verändert)
- [x] Negativ-Test bestanden
- [x] Report erfüllt BIBEL § 4 inkl. Restrisiko-Ausweis je Kandidat
- [x] tracking.md aktualisiert, Commit `sprint-05: totpfad-bestatter implementiert`

## 10. Entscheidungen während der Umsetzung

1. **Skill-Ordner-Pfad**: `skills/totpfad-bestatter/` (BIBEL-§-3-Konvention seit
   Sprint 29).
2. **Löschung bleibt reine SKILL.md-Instruktion, kein Skript**: `reachability.ps1`
   und `evidence.ps1` sind beide strikt read-only (wie von § 2.6 gefordert). Die
   eigentliche Löschung erfolgt als Edit-Aktion des Modells im Zielprojekt, NUR nach
   Step 7 der SKILL.md (Einzel-Freigabe) — es gibt bewusst kein `delete.ps1`, das
   das umgehen könnte.
3. **Coverage-Granularität ist datei-, nicht funktionsgenau**: exakt wie im
   Sprint-File spezifiziert ("pro Kandidaten-Datei"). Eine Datei mit mehreren
   Kandidaten (genutzte + tote Funktion) zeigt für beide dieselbe Datei-Coverage —
   dokumentierte, spezifikationskonforme Vereinfachung, kein Bug.
4. **`$matches` als Variablenname vermieden**: kollidiert mit PowerShells
   automatischer `$matches`-Variable (von `-match` befüllt) — `$refHits` verwendet,
   um Verwechslungsrisiko in künftigen Sprints zu vermeiden (kein Fehler
   ausgelöst, aber vorsorglich sauber gehalten).

## 11. Testergebnisse

**Smoke** (Fixture `skills/totpfad-bestatter/tests/fixture/`: `a.ts` exportiert
`usedFn` (von `b.ts` genutzt) und `deadFn` (ungenutzt), `c.ts` von niemandem
referenziert): `reachability.ps1` liefert `deadFn`, `run` (aus `b.ts`, ebenfalls
echt unreferenziert) und `orphanFn` als Symbol-Kandidaten — **`usedFn` erscheint
korrekt NICHT** (hartes Kriterium: keine False Positives erfüllt).
`b.ts`/`c.ts` als Datei-Kandidaten (beide echt unreferenziert). `evidence.ps1` mit
Mini-lcov (`a.ts`: 6/10, `b.ts`: 5/5 covered) korrekt angereichert; Log-Test mit
einer Mini-Logdatei bestätigt: `orphanFn` im Log gefunden (`logHits: 1`,
Lebens-Evidenz), `deadFn`/`run` mit `logHits: 0`.

**Akzeptanz** (`dreamzzz-api_vs/src`, nur statisch + Git-Alter, KEINE Löschung):
14 Symbol-Kandidaten, 0 Datei-Kandidaten (jede Quelldatei wird von `index.ts`
importiert). Alle Kandidaten sind `export interface`-Deklarationen, die nur
INNERHALB ihrer eigenen Datei genutzt werden (z. B. `Env` nur in `index.ts`,
`EntitlementResult` nur in `entitlements.ts`) — 3 Stichproben
(`EntitlementResult`, `Env`, `VisionV5Perspective`) per `grep -rn` gegen das
gesamte Projekt verifiziert: tatsächlich 0 dateiübergreifende Referenzen. Genau
die Art False-Positive-Klasse, die SKILL.md Step 5.1 explizit adressiert
(datei-lokale Typen sind nicht tot, nur nicht cross-file geteilt) — im Bericht
korrekt als "aussortiert, kein echter Totpfad" zu behandeln, nicht als
Bestattungsliste. Fremdprojekt unverändert (kein Edit ausgeführt).

**Negativ**: nicht existenter Pfad → beide Skripte `Write-Error` + Exit-Code 1.
SKILL.md-Review gegen § 6.4: Löschung ausschließlich in Step 7, ausschließlich
nach explizit benannter Einzel-Freigabe — keine pauschale/automatische
Lösch-Formulierung im Text.
