---
name: zeitbomben-scanner
description: "Time bomb scanner: finds hardcoded dates, expiry deadlines, cert references, 32-bit time usage and 'temporary' markers rotting since years (git age via blame), then has the LLM classify each finding as live bomb / rotten provisional / false alarm and produce a defusal list ranked by detonation date. Read-only. Trigger: /timebomb"
trigger: /timebomb
---

# /timebomb

Jede Codebase tickt. Diese hier weißt du, wann. Findet hartkodierte
Ablaufdaten, Ablauf-Schlüsselwörter, verrottete "temporär"-Marker (mit
Git-Alter) und 32-Bit-Zeit-Verdacht — priorisiert nach Zünddatum.

## What this is for

- Hartkodierte Jahreszahlen, Gutschein-Deadlines, "// temporär, wird nächste
  Woche entfernt" von vor Jahren — diese Bomben findet niemand, weil sie
  verstreut sind und erst am Zündtag explodieren.
- **Reiner Lese-Skill.** Keine automatische Entschärfung, keine
  Zertifikats-Dateien parsen (nur Pfade/Erwähnungen), keine externen
  Ablauf-Register.

## What You Must Do When Invoked

Wenn `/timebomb --help` oder `/timebomb -h` (ohne weitere Argumente)
aufgerufen wird: gib den Abschnitt `## Usage` unverändert aus und stoppe.

Sonst die folgenden Schritte der Reihe nach, keinen überspringen.

### Step 1 — Ziel klären

Kläre `-ProjectDir`. Heutiges Datum festhalten (Referenz für "überfällig").
Bestätigung einholen.

### Step 2 — Scan

```powershell
& "<SKILL_DIR>/scripts/timebomb-scan.ps1" -ProjectDir "<pfad>"
```

### Step 3 — Klassifikation

Jeden Fund im Kontext lesen (bei Unklarheit die Datei-Stelle per Read prüfen):

- **Scharfe Bombe**: Verhalten ändert sich an einem konkreten Datum. Zünddatum
  benennen; liegt es in der Vergangenheit → **überfällig** (höchste Priorität —
  die Bombe ist evtl. schon explodiert, mögliches Symptom beschreiben).
- **Verrottetes Provisorium**: `rotten`-Marker — was wollte der Autor, was ist
  das Risiko des Dauerzustands (Blame-Datum als Beleg).
- **Fehlalarm**: Jahreszahl in Copyright, Testdaten, Token-Limits (z. B.
  `maxOutputTokens: 2048`), Changelog — aussortieren, im Anhang listen. Der
  Collector meldet bewusst breit (auch freistehende Jahreszahlen ohne
  Vergleichs-Kontext); das Aussortieren ist hier Kernaufgabe, nicht Nebensache.
- **32-Bit-Funde**: nur melden, wenn der Typ tatsächlich Zeit speichert
  (`vermutet` bei Unsicherheit).

### Step 4 — Report schreiben

Datei `timebomb-report.md` im aktuellen Arbeitsverzeichnis:

1. **Kurzfassung** — Zählung: überfällig / tickt / verrottet.
2. **Entschärfungsliste** — sortiert: überfällig zuerst, dann nach Zünddatum
   aufsteigend, dann Provisorien nach Alter absteigend. Je Fund: Klasse,
   Zünddatum bzw. Alter, Evidenz (`Datei:Zeile`, Blame-Datum), konkreter
   Entschärfungs-Vorschlag.
3. **Fehlalarme** im Anhang.
4. **Offene Fragen**.

Evidenz-Pflicht: Zünddatum nur aus dem Literal, Alter nur aus Blame; kein
geschätztes Datum ohne Kennzeichnung `vermutet`.

### Step 5 — Zusammenfassen

Pfad des Reports nennen, die überfälligen Funde zuerst zusammenfassen.

## Usage

```
/timebomb               # interaktiv
/timebomb <dir>         # Projekt scannen
/timebomb --help
```
