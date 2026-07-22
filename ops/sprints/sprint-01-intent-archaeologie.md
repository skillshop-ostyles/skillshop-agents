# Sprint 01 — intent-archaeologie (/intent)

Regeln: `ops/BIBEL.md` gilt vollständig. Dieses File ist die Sprint-Spezifikation.

## 1. Problem

Code beantwortet nur "was", nie "warum". Nach Jahren weiß niemand mehr, warum eine
Funktion so gebaut ist, warum ein Workaround existiert, welche Ticket-Diskussion zu
einer merkwürdigen Bedingung führte. Das Wissen liegt verstreut in Commit-Messages,
Blame-Historie und Ticket-Referenzen — für Menschen unlesbar viel. Erst ein LLM kann
diese Fragmente zu einer kohärenten Warum-Geschichte verdichten.

## 2. Nutzen

Vorher: 2-4 Stunden Git-Archäologie von Hand pro "Warum ist das so?"-Frage, oft
ergebnislos. Nachher: ein Aufruf liefert die rekonstruierte Absichts-Geschichte einer
Datei oder eines Symbols mit Commit-Belegen in Minuten. Profiteure: jeder, der fremden
oder eigenen alten Code anfassen muss, bevor er ihn versteht.

## 3. Scope / Nicht-Scope

**Scope:** Analyse einer Datei oder eines Symbols (Funktion/Klasse per Namens-Match)
in einem Git-Repo. Evidenz: Commit-Historie, Blame, Ticket-IDs aus Messages.
**Nicht-Scope:** Kein Zugriff auf externe Ticket-Systeme (nur IDs extrahieren und
listen). Keine Analyse ganzer Verzeichnisbäume in einem Lauf (Datei für Datei). Keine
Code-Änderungen — reiner Lese-Skill.

## 4. Skill-Spezifikation

Ordner: `intent-archaeologie/`

Frontmatter für SKILL.md:

```yaml
---
name: intent-archaeologie
description: "Reconstructs WHY code exists the way it does: mines git history (log --follow, blame, ticket references) for a file or symbol, then has the LLM rebuild the intent story with commit-level evidence and confidence ratings. Read-only. Trigger: /intent"
trigger: /intent
---
```

Invocation-Steps (in SKILL.md ausformulieren):

1. `--help`/`-h` → Usage-Block ausgeben, stopp.
2. Ziel klären: `-ProjectDir` (Repo-Wurzel) + `-File` (repo-relativer Pfad) + optional
   `-Symbol` (Funktions-/Klassenname). Fehlt etwas, beim User erfragen. Bestätigung
   einholen (Muster elevate Step 1).
3. `scripts/git-mine.ps1` ausführen, JSON einlesen.
4. LLM-Analyse gemäß § 6 dieses Files.
5. Report als `intent-report-<dateiname>.md` ins aktuelle Arbeitsverzeichnis schreiben
   (nicht ins analysierte Repo), Pfad dem User nennen, Kernaussagen zusammenfassen.

Usage:

```
/intent                          # interaktiv: Repo, Datei, optional Symbol erfragen
/intent <repo> <datei>           # Datei-Analyse
/intent <repo> <datei> <symbol>  # Symbol-Analyse
/intent --help                   # Usage anzeigen, stopp
```

## 5. Collector-Skripte

### scripts/git-mine.ps1

Parameter: `-ProjectDir` (Pflicht), `-File` (Pflicht, repo-relativ), `-Symbol`
(optional), `-MaxCommits` (optional, Default 200).

Sammelt (read-only, kein Guard nötig, aber Existenz-Checks: ProjectDir vorhanden,
`.git` vorhanden, File vorhanden — sonst `Write-Error` + exit 1):

1. `git log --follow --format=... -- <File>` — Hash, Datum, Autor, Subject, Body
   (auf `-MaxCommits` begrenzt, älteste zuerst ausgeben).
2. Bei `-Symbol`: zusätzlich `git log -L :<Symbol>:<File>` (falls git das Symbol
   findet; Fehler abfangen → Feld `symbolLogAvailable: false`).
3. Ticket-IDs aus allen Messages: Regex `[A-Z][A-Z0-9]+-\d+` (JIRA-Stil) und
   `#\d+` (GitHub-Stil), dedupliziert.
4. Blame-Aggregation: `git blame --line-porcelain <File>` → pro Autor Zeilenanzahl,
   pro Commit Zeilenanzahl (Top 10).

JSON-Schema (Beispiel):

```json
{
  "file": "src/billing/invoice.ts",
  "symbol": "calculateTax",
  "symbolLogAvailable": true,
  "commits": [
    { "hash": "a1b2c3d", "date": "2019-03-04", "author": "X", "subject": "...", "body": "...", "tickets": ["PROJ-123"] }
  ],
  "ticketIds": ["PROJ-123", "#456"],
  "blame": { "byAuthor": [{ "author": "X", "lines": 120 }], "byCommit": [{ "hash": "a1b2c3d", "lines": 40 }] },
  "truncated": false
}
```

Danach Konsolen-Zusammenfassung: Commit-Anzahl, Zeitspanne, Top-Autoren, Ticket-IDs.

Fehlerverhalten: kein Git-Repo → klare Meldung + exit 1. Datei ohne Historie
(neu, uncommitted) → leeres `commits`-Array + Hinweis in Zusammenfassung, exit 0.

## 6. LLM-Analyse-Steps

Mit dem JSON:

1. Commits chronologisch lesen, Phasen bilden (Entstehung, Umbauten, Fixes, Workarounds).
2. Pro Phase die Absicht rekonstruieren: Was wurde versucht? Was hat es ausgelöst
   (Ticket, Bugfix-Formulierung, Revert)?
3. Auffälligkeiten explizit behandeln: Reverts, schnelle Folge-Fixes (< 2 Tage nach
   Change), Commits mit "hack", "workaround", "temp", "fix fix" o. ä.
4. Report-Struktur:
   - **Kurzfassung** (5 Sätze max): die Warum-Geschichte.
   - **Chronologie** — je Phase: Zeitraum, Absicht, Evidenz (Commit-Hashes), Konfidenz.
   - **Warnungen** — Workarounds/Provisorien, die nie aufgeräumt wurden (mit Beleg).
   - **Offene Fragen** — alles `vermutet`, plus die Ticket-IDs, die man nachschlagen
     müsste, um Lücken zu schließen.
5. Evidenz-Pflicht: jede Aussage mit Commit-Hash(es); Konfidenz-Stufen gemäß BIBEL § 4.

## 7. Edge-Cases

| Fall | Verhalten |
|---|---|
| Kein Git-Repo | git-mine.ps1: Fehler + exit 1; SKILL.md: User informieren, stopp |
| Datei nicht in Historie | Leeres commits-Array, Report sagt das explizit, keine Erfindungen |
| > MaxCommits Historie | Älteste + neueste bevorzugen? Nein: neueste `MaxCommits` nehmen, `truncated: true`, im Report ausweisen |
| Symbol von `git log -L` nicht auffindbar | `symbolLogAvailable: false`, Analyse fällt auf Datei-Ebene zurück, Report weist es aus |
| Umbenannte Datei | `--follow` deckt es ab; Umbenennung in Chronologie erwähnen |
| Riesige Datei (Blame langsam) | Kein Sonderfall nötig; bei > 60 s Laufzeit im Report vermerken |

## 8. Testplan

Smoke (gegen AGENTS-Repo selbst):

```powershell
& .\intent-archaeologie\scripts\git-mine.ps1 -ProjectDir "C:\Users\ostol\Desktop\AGENTS" -File "elevate/SKILL.md"
```

Erwartung: exit 0, JSON parsebar, mindestens 1 Commit (Initial-Commit), Zusammenfassung sichtbar.

Akzeptanz (dreamzzz-api): eine real existierende Quelldatei mit mehreren Commits wählen
(vorher mit `git -C <repo> log --oneline -- <datei>` prüfen; Repo-Wurzel ermitteln —
`src` kann Unterordner der Wurzel sein). Erwartung: Chronologie mit ≥ 2 Phasen ODER
dokumentiert, dass die Historie zu kurz ist; jede Behauptung mit Hash.

Negativ:

```powershell
& .\intent-archaeologie\scripts\git-mine.ps1 -ProjectDir "C:\gibt\es\nicht" -File "x"   # exit != 0, klare Meldung
& .\intent-archaeologie\scripts\git-mine.ps1 -ProjectDir "C:\Users\ostol\Desktop" -File "x"  # kein Repo -> exit != 0
```

## 9. DoD-Checkliste

- [x] SKILL.md vollständig (Frontmatter, Steps, Usage, --help)
- [x] git-mine.ps1: alle 4 Evidenz-Quellen, JSON-Schema eingehalten, Zusammenfassung
- [x] Smoke bestanden (JSON durch ConvertFrom-Json validiert)
- [x] Akzeptanz-Lauf dokumentiert (Kommando + Kern-Output hier unten anfügen)
- [x] Beide Negativ-Tests bestanden
- [x] Report-Beispiel erzeugt und gegen BIBEL § 4 geprüft (Evidenz + Konfidenz + Offene Fragen)
- [x] tracking.md aktualisiert, lokaler Commit `sprint-01: intent-archaeologie implementiert`

## 10. Entscheidungen während der Umsetzung

1. **Skill-Ordner-Pfad**: `skills/intent-archaeologie/` statt des im File oben
   genannten `intent-archaeologie/` — BIBEL § 3 wurde in Sprint 29 auf die
   `skills/`-Konvention umgestellt, gilt für alle folgenden Sprints.
2. **Record-/Feld-Trenner statt Newlines**: `git-mine.ps1` nutzt eigene
   Unit-/Record-Separatoren (`%x1f`/`%x1e`) im `--pretty=format`, weil PowerShell die
   Ausgabe externer Programme automatisch zeilenweise in ein Array zerlegt —
   mehrzeilige Commit-Bodies wurden dadurch zunächst zerrissen. Fix: Array vor dem
   Parsen mit `-join "`n"` wieder zu einem String zusammenfügen, danach auf den
   eigenen Separatoren splitten. Zusätzlich: an Rename-Übergängen (`--follow`) hängt
   git gelegentlich einen Stray-Newline an den Record-Anfang — jedes Feld wird daher
   getrimmt, bevor `Substring` auf den Hash angewendet wird.
3. **UTF-8-Encoding-Fix**: `[Console]::OutputEncoding`/`$OutputEncoding` müssen vor
   dem ersten `git`-Aufruf auf UTF8 gesetzt werden, sonst werden Umlaute/Sonderzeichen
   in Commit-Messages unter PowerShell 5.1 zu Mojibake. Beim Akzeptanz-Lauf gegen
   dreamzzz-api (echte deutsche Commit-Texte) gefunden und behoben.
4. **Falsch-positiver Ticket-Treffer bewusst akzeptiert**: die JIRA-Regex
   (`[A-Z][A-Z0-9]+-\d+`) matcht im Akzeptanz-Lauf auch "SHA-256" (aus
   "HMAC-SHA256..."). Exakt das im Sprint-File spezifizierte Muster — keine
   Abweichung ohne Rückfrage, im Report unter "Offene Fragen" transparent gemacht statt
   stillschweigend nachgeschärft.

## 11. Testergebnisse

**Smoke** (gegen AGENTS-Repo, `skills/elevate/SKILL.md` und `ops/tracking.md`):
exit 0, JSON via `ConvertFrom-Json` valide, 2 bzw. 12 Commits gefunden. Symbol-Lauf
gegen `shop/src/importer.js` / `scanSkillFolders` bestätigt `symbolLogAvailable: true`.

**Akzeptanz** (`dreamzzz-api_vs/src`, Datei `index.ts`, 5 Commits in der echten
Historie):

```
& skills/intent-archaeologie/scripts/git-mine.ps1 `
    -ProjectDir "C:\Users\ostol\Desktop\dreamzzz-api_vs\src" -File "index.ts"
```

Ergebnis: 5 Commits, chronologisch 2026-05-20 bis 2026-06-24, `truncated: false`,
1 Ticket-ID-Treffer (falsch-positiv, s. o.), Blame zeigt Haupt-Autor + 15 unkommittete
Zeilen ("Not Committed Yet" — realer Edge-Case, korrekt abgebildet). Vollständiger
Beispiel-Report mit 5 Phasen, Konfidenz-Stufen und "Offene Fragen"-Abschnitt erzeugt
und gegen BIBEL § 4 geprüft (Evidenz-Pflicht erfüllt: jede Aussage trägt einen
Commit-Hash oder ist explizit als `vermutet` markiert).

**Negativ**: nicht existenter Pfad → `Write-Error` "ProjectDir existiert nicht" +
Exit-Code 1. Kein Git-Repo (Wegwerf-Ordner ohne `.git`) → `Write-Error` "Kein
Git-Repo" + Exit-Code 1. Beide Fehlermeldungen identisch im Stil zum etablierten
`elevate/scripts/audit.ps1`-Muster (verifiziert durch direkten Vergleich) — kein
unkontrollierter Stack-Trace, klare Meldung + definierter Exit-Code.
