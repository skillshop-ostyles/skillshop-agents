---
name: totpfad-bestatter
description: "Dead-path undertaker: identifies provably unreachable code by combining static reachability (unreferenced exports/files), optional runtime evidence (coverage reports, logs) and git age, then produces a burial list ranked by evidence strength. NEVER deletes automatically - prepares patches for individual user approval only. Trigger: /bury"
trigger: /bury
---

# /bury

Identifiziert nachweislich unerreichbaren Code (statische Nichterreichbarkeit +
optionale Laufzeit-Evidenz + Git-Alter) und bestattet ihn — aber **niemals
automatisch**, nur nach deiner expliziten Einzel-Freigabe pro Kandidat.

## What this is for

- Tote Pfade (nie aufgerufene Funktionen, verwaiste Dateien) sicher identifizieren,
  statt aus Angst vor dem "einen versteckten Aufruf" nie zu löschen.
- Kombiniert statische Unerreichbarkeit mit Laufzeit-Evidenz (Coverage, Logs, wenn
  vorhanden) und Git-Historie zu einem belastbaren Urteil je Kandidat — inklusive
  ehrlicher Restrisiko-Angabe (Reflection/DI/Routen-Konventionen werden NICHT
  sicher erkannt).

## SCHUTZREGEL — niemals `~/.claude/`

Das Zielverzeichnis darf unter keinen Umständen `C:\Users\ostol\.claude\` (oder
dessen Unterordner) sein. Lehnt der User `~/.claude/` als Ziel vor, brich sofort ab.

## SCHUTZREGEL — Löschungen NUR nach Einzel-Freigabe

**Dieser Skill löscht NIEMALS automatisch.** Der Report ist immer nur ein
Vorschlag. Eine Löschung (Edit im Zielprojekt) erfolgt ausschließlich, wenn der
User EINEN KONKRETEN Kandidaten per Nummer/Namen explizit freigibt — niemals
pauschal ("lösch halt alles"), niemals ohne Rückfrage. Ohne jede Freigabe endet
der Ablauf beim Report.

## What You Must Do When Invoked

Wenn `/bury --help` oder `/bury -h` (ohne weitere Argumente) aufgerufen wird: gib
den Abschnitt `## Usage` unverändert aus und stoppe.

Sonst die folgenden Schritte der Reihe nach, keinen überspringen.

### Step 1 — Ziel klären

Kläre `-ProjectDir` (nicht `~/.claude/`, siehe Schutzregel) und optional Pfade zu
einem Coverage-Report (`coverage-summary.json` oder `lcov.info`) und/oder einem
Log-Verzeichnis. Bestätigung einholen.

### Step 2 — Statische Erreichbarkeit

```powershell
& "<SKILL_DIR>/scripts/reachability.ps1" -ProjectDir "<pfad>"
```

Ausgabe in eine Datei umleiten (für Step 3 als `-Candidates` gebraucht).

### Step 3 — Laufzeit-Evidenz (falls angegeben)

```powershell
& "<SKILL_DIR>/scripts/evidence.ps1" -ProjectDir "<pfad>" -Candidates "<datei-aus-step-2>" [-CoverageFile "<pfad>"] [-LogDir "<pfad>"]
```

Ohne Coverage/Logs: mit den reinen Reachability-Daten aus Step 2 weiterarbeiten,
die fehlende Laufzeit-Evidenz im Report ausweisen.

### Step 4 — Alters-Evidenz

Pro Kandidat: `git -C "<ProjectDir>" log -1 --format=%ci -- "<datei>"` (kein
eigenes Skript nötig). Kein Git-Repo: Alters-Evidenz entfällt, im Report ausweisen.

### Step 5 — Analyse

1. Kandidaten plausibilisieren: bekannte False-Positive-Klassen aktiv prüfen und
   AUSSORTIEREN oder herabstufen — Framework-Konventionen (Routen-Handler,
   Lifecycle-Methoden, DI-Registrierungen, Reflection-Strings, dynamische Importe,
   öffentliche Paket-API bei Libraries — `package.json`/`pyproject.toml`
   `main`/`exports` prüfen). Jede Aussortierung begründen.
2. Evidenz-Stärke je verbleibendem Kandidat:
   - **Stark**: 0 Referenzen + 0 Coverage + keine Log-Treffer + > 2 Jahre unberührt.
   - **Mittel**: 0 Referenzen + (Coverage ODER Alter), keine Laufzeit-Daten dagegen.
   - **Schwach**: nur statisch, junge Datei oder keine Laufzeit-Daten vorhanden.
3. Sehr generischer Symbolname: Referenz-Zählung ist unzuverlässig — Trefferkontext
   prüfen, sonst herabstufen.
4. Evidenz-Pflicht: kein Kandidat ohne vollständige Evidenz-Zeile (Refs, Coverage,
   Logs, Alter — auch wenn ein Feld "keine Daten" ist, explizit nennen).

### Step 6 — Report schreiben

Datei `bury-report.md` im aktuellen Arbeitsverzeichnis (**nicht** ins analysierte
Repo):

1. **Kurzfassung** — X Kandidaten: stark/mittel/schwach.
2. **Bestattungsliste** — sortiert nach Stärke, je Kandidat: alle Evidenz (Refs,
   Coverage, Logs, letzter Commit + Hash), Restrisiko-Hinweis (welche dynamische
   Aufrufart NICHT ausgeschlossen werden konnte), Diff-Vorschau der Löschung.
3. **Aussortierte** — mit Begründung.
4. **Offene Fragen**.

### Step 7 — Freigabe einholen, NUR dann löschen

Report zusammenfassen, dann fragen: "Welche Kandidaten (Nummer) sollen bestattet
werden?" Nur die einzeln benannten Kandidaten per Edit im Zielprojekt löschen —
niemals mehr als explizit genannt. Nach jeder Löschung: dem User empfehlen, Build
und Tests des Zielprojekts laufen zu lassen. Keine Antwort/keine Freigabe: Ablauf
endet beim Report, nichts wird verändert.

## Usage

```
/bury                                # interaktiv
/bury <dir>                          # nur statisch + git-Alter
/bury <dir> -coverage <report>       # plus Coverage-Evidenz
/bury <dir> -logs <logdir>           # plus Log-Evidenz
/bury --help
```
