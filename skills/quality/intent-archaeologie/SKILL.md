---
name: intent-archaeologie
description: "Reconstructs WHY code exists the way it does: mines git history (log --follow, blame, ticket references) for a file or symbol, then has the LLM rebuild the intent story with commit-level evidence and confidence ratings. Read-only. Trigger: /intent"
trigger: /intent
---

# /intent

Rekonstruiert die Absichts-Geschichte einer Datei (oder eines Symbols darin) aus
Git-Historie, Blame und Ticket-Referenzen — mit Commit-Belegen statt Vermutungen.

## What this is for

- Fremden oder eigenen alten Code verstehen, bevor man ihn anfasst: warum ist das so
  gebaut, warum existiert dieser Workaround, welche Diskussion führte zu einer
  merkwürdigen Bedingung?
- Ersetzt 2-4 Stunden manuelle Git-Archäologie durch einen Aufruf mit
  Commit-Belegen in Minuten.
- **Reiner Lese-Skill.** Analysiert eine Datei oder ein Symbol (Funktion/Klasse) pro
  Lauf, keine Verzeichnisbäume in einem Rutsch, kein Zugriff auf externe
  Ticket-Systeme (nur IDs extrahieren und auflisten).

## What You Must Do When Invoked

Wenn `/intent --help` oder `/intent -h` (ohne weitere Argumente) aufgerufen wird: gib
den Abschnitt `## Usage` unverändert aus und stoppe.

Sonst die folgenden Schritte der Reihe nach, keinen überspringen.

### Step 1 — Ziel klären

Kläre: `-ProjectDir` (Repo-Wurzel oder ein Unterordner davon), `-File`
(repo-relativ zu `-ProjectDir`), optional `-Symbol` (Funktions-/Klassenname). Fehlt
etwas, beim User erfragen. Zeige, was erkannt wurde, dann:

```
ProjectDir: <pfad>
Datei:      <datei>
Symbol:     <symbol oder "keins">
Fortfahren? (yes/no)
```

Erst nach Bestätigung weiter.

### Step 2 — Evidenz sammeln

```powershell
& "<SKILL_DIR>/scripts/git-mine.ps1" -ProjectDir "<pfad>" -File "<datei>" [-Symbol "<symbol>"]
```

JSON-Ausgabe einlesen. Bricht das Skript mit Exit-Code ≠ 0 ab (kein Git-Repo, Pfad
fehlt, Datei fehlt): die `Write-Error`-Meldung dem User zeigen, stoppen.

### Step 3 — Analyse

Mit dem JSON aus Step 2:

1. Commits chronologisch lesen (das Skript liefert sie bereits ältest-zuerst),
   Phasen bilden (Entstehung, Umbauten, Fixes, Workarounds).
2. Pro Phase die Absicht rekonstruieren: Was wurde versucht? Was hat es ausgelöst
   (Ticket-ID, Bugfix-Formulierung, Revert)?
3. Auffälligkeiten explizit behandeln: Reverts, schnelle Folge-Fixes (< 2 Tage nach
   dem vorherigen Change), Commits mit "hack", "workaround", "temp", "fix fix" o. Ä.
4. Ist `symbol` gesetzt aber `symbolLogAvailable: false`: das im Report vermerken,
   Analyse fällt auf Datei-Ebene zurück.
5. Jede Aussage bekommt eine Konfidenz-Stufe (`belegt` / `wahrscheinlich` /
   `vermutet`) gemäß `ops/BIBEL.md` § 4. `vermutet`-Aussagen gehören ausschließlich
   in den Abschnitt "Offene Fragen", nie zwischen die belegten Befunde.

### Step 4 — Report schreiben

Report-Struktur (Markdown):

1. **Kurzfassung** (max. 5 Sätze) — die Warum-Geschichte in Kürze.
2. **Chronologie** — je Phase: Zeitraum, rekonstruierte Absicht, Evidenz
   (Commit-Hashes), Konfidenz-Stufe.
3. **Warnungen** — Workarounds/Provisorien, die nie aufgeräumt wurden, mit Beleg.
4. **Offene Fragen** — alle `vermutet`-Einstufungen, plus Ticket-IDs aus `ticketIds`,
   die man nachschlagen müsste, um Lücken zu schließen.

Speichere den Report als `intent-report-<dateiname>.md` im aktuellen
Arbeitsverzeichnis (**nicht** ins analysierte Repo schreiben).

### Step 5 — Zusammenfassen

Nenne dem User den Pfad des geschriebenen Reports und fasse die Kernaussagen (2-3
Sätze) direkt im Chat zusammen.

## Usage

```
/intent                          # interaktiv: Repo, Datei, optional Symbol erfragen
/intent <repo> <datei>           # Datei-Analyse
/intent <repo> <datei> <symbol>  # Symbol-Analyse
/intent --help                   # Usage anzeigen, stopp
```
