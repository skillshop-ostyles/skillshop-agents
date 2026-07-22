---
name: prod-spiegel
description: "Production behavior mirror: ingests exported log files (text or JSON lines), statistically condenses them (frequencies, error rates, hot paths), extracts the code's expectations (log statements, catch blocks, routes), then has the LLM report the deltas - dead features, swallowed errors firing daily, unexpected hot paths. Works fully offline on exported logs. Read-only. Trigger: /mirror"
trigger: /mirror
---

# /mirror

Was dein Code verspricht, und was Prod wirklich tut, sind zwei Geschichten.
Gleicht exportierte Logs statistisch gegen Code-Erwartungen ab: tote Features,
verschluckte Fehler, unerwartete Hot Paths, "unmögliche" Zustände, die trotzdem
feuern.

## What this is for

- Prod-Realität kennt sonst niemand ganz; Abschalt-/Priorisierungs-Entscheidungen
  basieren auf Meinung statt Beleg. Funktioniert komplett offline auf exportierten
  Log-Dateien (Text oder JSON-Lines) — keine Live-Anbindung an
  Observability-Plattformen.
- **Reiner Lese-Skill.** Keine PII-Verarbeitung: E-Mail-Adressen und lange
  Ziffernfolgen werden in ALLEN Ausgaben maskiert, nicht nur in Beispielen.

## What You Must Do When Invoked

Wenn `/mirror --help` oder `/mirror -h` (ohne weitere Argumente) aufgerufen wird:
gib den Abschnitt `## Usage` unverändert aus und stoppe.

Sonst die folgenden Schritte der Reihe nach, keinen überspringen.

### Step 1 — Ziel klären

Kläre `-ProjectDir` (Code), `-LogDir` (exportierte Logs) und eine grobe Angabe
des Log-Zeitraums (Freitext, für die Einordnung im Report). Bestätigung einholen.

### Step 2 — Evidenz sammeln

```powershell
& "<SKILL_DIR>/scripts/log-ingest.ps1" -LogDir "<logdir>"
& "<SKILL_DIR>/scripts/code-claims.ps1" -ProjectDir "<pfad>"
```

Leeres/fehlendes LogDir: das Skript bricht mit Exit-Code 1 ab (ohne Logs ist der
Abgleich sinnlos) — Meldung weitergeben, stoppen.

### Step 3 — Abgleich in vier Richtungen

Jede Richtung aktiv durchführen, nicht nur notieren, was zufällig auffällt:

1. **Code erwartet, Logs schweigen** → tote Feature-Kandidaten: Routen und
   Log-Messages, deren Muster in den Logs nicht vorkommen. Vorsicht: Log-Level
   kann in Prod gefiltert sein — prüfen, ob ÜBERHAUPT info-Zeilen im Log
   vorkommen; sonst diese Richtung auf error/warn begrenzen und die Einschränkung
   ausweisen.
2. **Logs schreien, Code verschluckt** → Error-Muster mit hoher Frequenz, deren
   Ursprung ein `swallowGuess`-Catch oder ein Log ohne weitere Behandlung ist —
   die "stillen Dauerbrenner". Mapping über Message-Literal-Ähnlichkeit (wörtlich
   > normalisiert > semantisch; Konfidenz entsprechend `belegt`/`wahrscheinlich`/
   `vermutet`).
3. **Unerwartete Hot Paths** → Top-Muster nach Häufigkeit, deren Code-Stellen
   unscheinbar wirken (Retry-Schleifen, Fallbacks) — benennen, was die Häufigkeit
   über das Systemverhalten aussagt.
4. **"Unmögliche" Zustände** → Log-Muster mit "should never happen"-Charakter
   (Message enthält never/unreachable/unexpected/impossible), die trotzdem
   zählbar feuern.

Logs von einem anderen Service (Mapping-Quote ~0): Warnung "Logs passen evtl.
nicht zum Projekt" statt Nonsens-Deltas zu erfinden.

### Step 4 — Report schreiben

Datei `mirror-report.md` im aktuellen Arbeitsverzeichnis:

1. **Kurzfassung** — Kennzahlen + 3 wichtigste Deltas.
2. Die vier Delta-Kategorien mit Evidenz (Log-Muster + Count + Zeitraum,
   Code-Stelle `Datei:Zeile`).
3. **Empfehlungen** — konkret ("Catch in X:123 loggt nicht — Fehler seit 6 Wochen
   8123×").
4. **Offene Fragen** — alle `vermutet`-Mappings, Log-Level-Einschränkungen.

Evidenz-Pflicht: jedes Delta braucht BEIDE Seiten (Code-Stelle UND
Log-Statistik) oder wird als einseitig gekennzeichnet.

### Step 5 — Zusammenfassen

Pfad des Reports nennen, die 3 wichtigsten Deltas direkt im Chat zusammenfassen.

## Usage

```
/mirror                          # interaktiv
/mirror <repo> <logdir>          # Abgleich Code vs. Logs
/mirror --help
```
