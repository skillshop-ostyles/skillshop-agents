---
name: repro-automat
description: "Turns a vague bug report into a minimal, runnable reproduction: extracts hypotheses from the report text, snapshots the environment, generates a repro test/script, EXECUTES it and iterates (max 5 attempts) until the bug demonstrably reproduces - or documents precisely which information is missing. The repro lives outside the target project. Trigger: /repro"
trigger: /repro
---

# /repro

Verwandelt einen vagen Bug-Report in einen minimalen, tatsächlich AUSGEFÜHRTEN
Repro-Test — oder eine präzise Liste, welche Information zum Reproduzieren fehlt.

## What this is for

- "Geht nicht" ist der teuerste Satz der Branche. Statt zu raten, extrahiert dieser
  Skill Hypothesen aus dem Report, generiert einen Repro-Kandidaten, FÜHRT IHN AUS
  und iteriert anhand des Ergebnisses.
- **Kein Fix** — Repro ist das Produkt, ein Fix ist ein Folgeauftrag. Keine
  UI-/Browser-Reproduktion (nur Code-Ebene). Keine Produktions-Datenbanken —
  nur lokale/synthetische Daten.
- Repro-Artefakte leben **immer im Arbeitsverzeichnis** (`repro/`-Unterordner),
  **niemals im Zielprojekt**.

## What You Must Do When Invoked

Wenn `/repro --help` oder `/repro -h` (ohne weitere Argumente) aufgerufen wird:
gib den Abschnitt `## Usage` unverändert aus und stoppe.

Sonst die folgenden Schritte der Reihe nach, keinen überspringen.

### Step 1 — Ziel und Bug-Report klären

Kläre `-ProjectDir` und den Bug-Report (Freitext einfügen lassen oder Datei-Pfad).
Bestätigung einholen.

### Step 2 — Umgebungs-Snapshot

```powershell
& "<SKILL_DIR>/scripts/env-snapshot.ps1" -ProjectDir "<pfad>"
```

Das Ergebnis (Stack, Runtimes, Test-Runner, Git-Zustand, Entry-Points) fließt
später ins Protokoll — es hält fest, GEGEN welchen Stand reproduziert wurde.

### Step 3 — Report sezieren

Symptom (was passiert), Erwartung (was sollte passieren), Auslöser-Kandidaten
(Eingaben, Reihenfolge, Zustand), Umgebungs-Hinweise. Fehlende Kern-Angaben SOFORT
als "fehlende Infos" notieren — aber trotzdem mit Hypothesen weitermachen, nicht
vorschnell aufgeben.

### Step 4 — Verdächtigen Code lokalisieren

Aus Symptom-Begriffen + Stacktrace (falls vorhanden) die relevanten Dateien finden
(Grep) und vollständig lesen (Read). Hypothesen bilden: unter welchen Bedingungen
erzeugt dieser Code das Symptom? Nach Wahrscheinlichkeit ordnen.

Kein verwertbarer Hinweis im Report: EINEN Hypothesen-Versuch aus reiner
Code-Lektüre unternehmen, dann früh mit einer Rückfragen-Liste abbrechen — nicht 5
Blind-Versuche verbrennen.

### Step 5 — Repro-Schleife (max. 5 Versuche)

Pro Versuch:

1. Repro-Artefakt im Arbeitsverzeichnis unter `repro/` generieren (niemals im
   Zielprojekt): bevorzugt ein Test im Stil des erkannten Test-Runners, der das
   Zielprojekt importiert/aufruft; sonst ein Standalone-Skript. Minimal: ein
   Szenario, eine harte Assertion auf das ERWARTETE Verhalten — der Test MUSS beim
   Vorliegen des Bugs fehlschlagen (das ist die Beweis-Logik).
2. Ausführen (Bash/PowerShell je nach Stack), Ergebnis interpretieren:
   - Assertion schlägt mit dem berichteten Symptom fehl → **reproduziert**.
     Artefakt minimieren (Unnötiges entfernen, nochmal laufen lassen — muss rot
     bleiben).
   - Test grün oder anderes Symptom → Hypothese verwerfen/verfeinern, nächster
     Versuch.
3. Jeden Versuch im Protokoll festhalten (Hypothese, Artefakt-Version, Ergebnis
   inkl. wörtlichem Output).
4. Externe Services (DB, API) nötig: mit Stubs/Fakes im Artefakt arbeiten; wenn
   unmöglich, als fehlende Info dokumentieren statt zu raten.
5. Heisenbug-Verdacht (Timing/Race): Artefakt mit Wiederholungsschleife (N Läufe,
   Fehlerquote messen); "reproduziert" ab nachweisbarer Quote, Quote im Protokoll.
6. Test-Runner-Installation fehlt im Zielprojekt: Standalone-Skript statt Test,
   nichts im Zielprojekt installieren.

### Step 6 — Abschluss

`repro/`-Ordner im Arbeitsverzeichnis mit Repro-Artefakt + `repro-protokoll.md`:

- **Reproduziert**: Umgebungs-Snapshot, finales Artefakt, exakte Ausgabe des roten
  Laufs (wörtlich), Einordnung (welche Hypothese traf zu, `belegt` durch
  Lauf-Output). Hinweis: Artefakt eignet sich als Regressionstest.
- **Nicht reproduziert** (nach bis zu 5 Versuchen): alle Versuche im Protokoll +
  präzise Liste fehlender Infos als kopierfertige Rückfragen an den Melder
  ("Welche Locale?", "Welche Datenmenge?"). Niemals "cannot reproduce" OHNE diese
  Liste.

Evidenz-Pflicht: "reproduziert" nur mit wörtlicher Fehlerausgabe des Laufs im
Protokoll. Hypothesen ohne Lauf sind maximal `vermutet`.

### Step 7 — Zusammenfassen

Kurz: reproduziert ja/nein, wie, was (falls nicht reproduziert) fehlt.

## Usage

```
/repro                          # interaktiv
/repro <repo>                   # Report wird abgefragt
/repro <repo> <report-datei>    # Report aus Datei
/repro --help
```
