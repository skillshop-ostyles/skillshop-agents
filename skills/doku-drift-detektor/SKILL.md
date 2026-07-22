---
name: doku-drift-detektor
description: "Documentation drift detector: extracts verifiable claims from a repo's markdown docs (file paths, commands/scripts, config keys, endpoints, versions, referenced symbols) and statically verifies each one against the actual code, reporting every stale claim with a concrete fix suggestion. Never executes documented commands. Read-only. Trigger: /doc-drift"
trigger: /doc-drift
---

# /doc-drift

Dein README lügt seit sechs Monaten. Zeit, es zu ertappen. Extrahiert prüfbare
Behauptungen aus der Doku (Pfade, Kommandos, Config-Schlüssel, Endpoints,
Versionen, Symbol-Referenzen) und hält jede statisch gegen die Code-Realität.

## What this is for

- README nennt Kommandos, die es nicht mehr gibt, Pfade, die umgezogen sind,
  Env-Vars, die umbenannt wurden — niemand prüft das systematisch, weil es
  stupide Fleißarbeit in großer Menge ist.
- **Reiner Lese-Skill. Dokumentierte Kommandos werden NIEMALS ausgeführt** —
  rein statischer Abgleich (Sicherheit vor Vollständigkeit). Keine externen
  Links, keine Prosa-Bewertung.

## What You Must Do When Invoked

Wenn `/doc-drift --help` oder `/doc-drift -h` (ohne weitere Argumente)
aufgerufen wird: gib den Abschnitt `## Usage` unverändert aus und stoppe.

Sonst die folgenden Schritte der Reihe nach, keinen überspringen.

### Step 1 — Ziel klären

Kläre `-ProjectDir`. Bestätigung einholen.

### Step 2 — Scan

```powershell
& "<SKILL_DIR>/scripts/claim-extract.ps1" -ProjectDir "<pfad>"
```

Wenn `docFiles` leer ist: dem User mitteilen, dass keine Doku-Dateien gefunden
wurden (README*/*.md/docs/**/*.md/CONTRIBUTING*), stoppen.

### Step 3 — Verifikation (NIE Kommandos ausführen)

Jeden Claim statisch gegen das Repo prüfen (Grep/Glob/Read):

- **path**: existiert Datei/Verzeichnis? Bei Fehlschlag: ähnliche Pfade suchen
  (umgezogen?) → Korrektur-Vorschlag.
- **command**: npm-Skripte gegen `package.json` `scripts` (analog
  Makefile-Targets, pyproject-Skripte) abgleichen — nur Existenz-Logik,
  **niemals ausführen**. Nicht statisch prüfbar → `nicht-prüfbar`.
- **config**: Schlüssel im Code/Config gegreppt — wird er gelesen/definiert?
- **endpoint**: Route im Code vorhanden?
- **version**: gegen engines/target-Angaben in Manifesten halten.
- **symbol**: existiert der Bezeichner im Code (Wortgrenzen-Grep)?

Sonderfälle: Futur-Ankündigungen ("wird bald…") → `nicht-prüfbar`, nicht Drift.
Platzhalter (`<your-key>`, `$VAR`) normalisieren, nur Struktur prüfen.
Monorepo: Pfad relativ zum Doku-Verzeichnis UND zur Repo-Wurzel versuchen.
Auto-generierte Doku (Generator-Marker) ausschließen, nur listen. Anker-Links
(`#abschnitt`) nicht prüfen (Nicht-Scope).

Urteil je Claim: `korrekt` / `DRIFT` (mit beiden Fundstellen: Doku-Zeile +
Repo-Beleg bzw. Fehlanzeige) / `nicht-prüfbar` (mit Grund). Severity für
Drift: `hoch` (Kommando/Pfad im Setup-Weg) / `mittel` / `niedrig`.

### Step 4 — Report schreiben

Datei `doc-drift-report.md` im aktuellen Arbeitsverzeichnis:

1. **Kurzfassung** — Claims gesamt, Drift-Quote, hoch-Severity-Funde.
2. **Drift-Funde** nach Severity, je Fund: Korrektur-Vorschlag (konkreter
   Ersatztext).
3. **Nicht-prüfbar-Liste**.
4. **Korrekt-Zählung**.
5. **Offene Fragen**.

Evidenz-Pflicht: jedes Drift-Urteil mit beiden Fundstellen.

### Step 5 — Zusammenfassen

Pfad des Reports nennen, Drift-Quote und hoch-Severity-Funde zuerst.

## Usage

```
/doc-drift               # interaktiv
/doc-drift <dir>         # Repo-Doku prüfen
/doc-drift --help
```
