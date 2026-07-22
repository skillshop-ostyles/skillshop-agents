---
name: seiteneffekt-radar
description: "Blast-radius predictor for a planned change: combines a static reference scan (which files mention the target's exported symbols) with git co-change analysis (which files historically changed together with the target), then produces a risk-tiered report with concrete review/test recommendations. Read-only. Trigger: /blast"
trigger: /blast
---

# /blast

Kombiniert statische Referenz-Suche mit historischer Co-Change-Analyse (welche
Dateien in der Vergangenheit fast immer gemeinsam mit dem Ziel geändert wurden) zu
einem risikogestuften Blast-Radius-Report vor einem geplanten Change.

## What this is for

- Vor einem riskanten Change wissen, was betroffen ist — nicht nur statisch
  (Referenzen), sondern auch historisch gekoppelt (Dateien ohne Import-Beziehung,
  die aber immer gemeinsam geändert wurden).
- **Reiner Lese-Skill.** Kein echter AST/Typgraph — textbasierte, sprachagnostische
  Referenz-Suche auf Grep-Niveau reicht für Risiko-Hinweise (Simplicity First).
  Keine dynamische Analyse.

## What You Must Do When Invoked

Wenn `/blast --help` oder `/blast -h` (ohne weitere Argumente) aufgerufen wird: gib
den Abschnitt `## Usage` unverändert aus und stoppe.

Sonst die folgenden Schritte der Reihe nach, keinen überspringen.

### Step 1 — Ziel und Change klären

Kläre: `-ProjectDir` (Repo-Wurzel oder Unterordner davon), Ziel-Datei(en) (der
geplante Change-Ort), und eine kurze Freitext-Beschreibung des geplanten Changes
(bestimmt, welche Symbole relevant sind — z. B. "Signatur von X ändern" vs. "interne
Optimierung"). Fehlt etwas, erfragen. Bestätigung einholen:

```
ProjectDir: <pfad>
Ziel-Datei(en): <dateien>
Geplanter Change: <freitext>
Fortfahren? (yes/no)
```

### Step 2 — Symbole identifizieren

Ziel-Datei(en) mit dem Read-Tool lesen, exportierte/öffentliche Symbole
identifizieren (sprachabhängig, kein Skript — bei Unsicherheit alle
Top-Level-Bezeichner nehmen).

### Step 3 — Evidenz sammeln

```powershell
& "<SKILL_DIR>/scripts/ref-scan.ps1" -ProjectDir "<pfad>" -Symbols <symbole>
& "<SKILL_DIR>/scripts/co-change.ps1" -ProjectDir "<pfad>" -Files <zieldateien>
```

Bricht `co-change.ps1` mit "Kein Git-Repo" ab: mit `ref-scan.ps1` allein
weiterarbeiten, die fehlende historische Analyse im Report explizit ausweisen
(kein Abbruch — Edge-Case des Sprint-Files).

### Step 4 — Analyse

1. Statische Treffer aus `ref-scan.ps1` bewerten: echte Nutzung vs.
   Namenskollision/Kommentar/String (der Zeileninhalt liegt vor). Kollisionen
   aussortieren, aber im Report-Anhang listen.
2. Risiko-Stufen bilden:
   - **Stufe 1 — direkt betroffen** (`belegt`): Dateien mit echter Symbol-Nutzung.
   - **Stufe 2 — historisch gekoppelt** (`wahrscheinlich`): Co-Change-Ratio ≥ 0.4
     ohne statische Referenz — die gefährlichste Kategorie. Explizit erklären, WARUM
     die Kopplung bestehen könnte (aus Dateinamen/Pfaden ableiten), Konfidenz ehrlich
     angeben.
   - **Stufe 3 — Umfeld**: schwache Kopplung (Ratio < 0.4, ≥ MinCoChanges), nur
     listen.
3. Die Change-Beschreibung des Users einbeziehen: welche Stufe-1/2-Stellen sind vom
   KONKRETEN Change betroffen.
4. `capped: true` bei einem Symbol: im Report vermerken, dass das Symbol zu
   generisch für eine vollständige statische Analyse war.

### Step 5 — Report schreiben

Datei `blast-report-<datei>.md` im aktuellen Arbeitsverzeichnis (**nicht** ins
analysierte Repo):

1. **Kurzfassung** — Risiko-Einschätzung in 3 Sätzen.
2. **Stufe 1 — direkt betroffen** — mit `Datei:Zeile`.
3. **Stufe 2 — historisch gekoppelt** — mit Kopplungszahlen (n von N Commits, Ratio)
   und der vermuteten Erklärung.
4. **Stufe 3 — Umfeld** — kurze Liste.
5. **Empfehlungen** — konkret ("vor Merge: Test X laufen lassen, Datei Y reviewen,
   Owner von Z informieren").
6. **Offene Fragen**.

### Step 6 — Zusammenfassen

Pfad des Reports nennen, Kurzfassung direkt im Chat wiedergeben.

## Usage

```
/blast                          # interaktiv
/blast <repo> <datei> [...]     # Blast-Radius für geplanten Change an <datei>
/blast --help
```
