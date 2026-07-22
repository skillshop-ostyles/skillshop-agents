---
name: wissens-testament
description: "Knowledge testament: mines git blame/log to map where one developer's exclusive knowledge lives (sole-author hotspots, high-churn areas they own), generates a targeted interview asking exactly the questions nobody would know to ask, and writes a structured, code-linked testament document. Read-only towards the repo. Trigger: /testament"
trigger: /testament
---

# /testament

Mint Git-Ownership, um zu finden, wo das Alleinwissen einer Person steckt, und
führt darauf ein gezieltes Übergabe-Interview — verlinkt auf Code, ehrlich über
seine eigenen Lücken.

## What this is for

- Wenn jemand geht (Kündigung, Sabbatical, Teamwechsel) oder präventiv als
  "lebendes Testament": implizites Wissen ist per Definition unsichtbar für den
  Träger selbst — dieser Skill leitet aus der Git-Historie ab, WO das Wissen
  steckt, und stellt genau die Fragen, die sonst niemand stellen würde.
- **Read-only gegenüber dem Repo.** Keine Bewertung von Personen (keine
  "Performance"-Aussagen — nur eine Wissens-Landkarte). Keine automatischen
  Mails/Exporte.

## What You Must Do When Invoked

Wenn `/testament --help` oder `/testament -h` (ohne weitere Argumente) aufgerufen
wird: gib den Abschnitt `## Usage` unverändert aus und stoppe.

Sonst die folgenden Schritte der Reihe nach, keinen überspringen.

### Step 1 — Ziel und Autor klären

Kläre `-ProjectDir` und den Autor (Name/E-Mail wie in Git):

```powershell
& "<SKILL_DIR>/scripts/ownership.ps1" -ProjectDir "<pfad>" -ListAuthors
```

zeigt Kandidaten mit Commit-Zahlen. Mehrere Git-Identitäten derselben Person
(unterschiedliche E-Mails): alle zugehörigen Einträge als `-Author`-Werte
mitgeben (Skript akzeptiert ein Array). Bestätigung einholen.

### Step 2 — Ownership-Mining

```powershell
& "<SKILL_DIR>/scripts/ownership.ps1" -ProjectDir "<pfad>" -Author <werte>
```

Kein Commit für den Autor gefunden: die `Write-Error`-Meldung (zeigt auf
`-ListAuthors`) direkt weitergeben, stoppen.

### Step 3 — Interview (blockweise, pausierbar)

1. Aus dem JSON eine **Wissens-Landkarte** bauen: Bereiche, Exklusivitätsgrad,
   Interview-Priorität (kritisches Alleinwissen aus `criticalExclusive` zuerst).
2. Interview blockweise führen, **pro Block max. 3 Fragen**, dann Antworten in
   einer Zeile reflektieren und nachfassen. Jede Frage braucht einen konkreten
   Anker aus der Evidenz (Datei + Blame-Anteil, oder Commit-Hash + Subject) —
   niemals generische Fragen wie "Was ist wichtig?". Vier Fragen-Typen:
   - **Entscheidung**: "Du hast `<datei>` zu `<blameShare>` geschrieben (Anker-Commit
     `<hash>`: `<subject>`) — was war am ersten Ansatz falsch/anders geplant?"
   - **Falle**: "Was passiert, wenn jemand `<datei>` 'vereinfacht'? Wo bricht es
     zuerst?"
   - **Kontext**: "Welche externe Randbedingung erklärt `<subject>` (Commit
     `<hash>`)?"
   - **Übergabe**: "Was sollte dein Nachfolger in `<datei>` in Woche 1 NICHT
     anfassen?"
3. **Pausierbarkeit**: nach jedem Block den Zwischenstand sofort als
   `testament-draft.md` im aktuellen Arbeitsverzeichnis sichern. Der User kann
   jederzeit abbrechen und später fortsetzen.
4. **Abwesenheits-Modus**: ist der Wissensträger nicht verfügbar, trotzdem alle
   Interview-Fragen generieren und als Fragenkatalog ausgeben — klar als
   "Testament in Abwesenheit / reduzierter Modus" kennzeichnen, keine Antworten
   erfinden.
5. Evidenz-Regel (angepasst gegenüber `ops/BIBEL.md` § 4): Interview-Aussagen
   sind als solche gekennzeichnet (Quelle: Interview, Datum) — sie brauchen
   keinen Commit-Beleg, aber jeden Code-Bezug als `Datei:Zeile`/Commit verlinken,
   wo möglich.

### Step 4 — Report schreiben

`testament-<autor>.md` ins aktuelle Arbeitsverzeichnis (**nicht** ins Repo):

1. **Wissens-Landkarte** — Tabelle: Bereich, Exklusivität, Risiko.
2. Pro Bereich: **Entscheidungen** (mit Commit-Belegen), **Fallen** (wörtlich aus
   dem Interview, mit Datei-Links), **Kontextwissen**.
3. **Woche-1-Warnliste** für den Nachfolger.
4. **Offene Punkte** — nicht gestellte/unbeantwortete Fragen. Das Testament ist
   ehrlich über seine eigenen Lücken.

### Step 5 — Zusammenfassen

Pfad des Reports nennen, Kurz-Zusammenfassung geben.

## Usage

```
/testament                       # interaktiv
/testament <repo> <autor>        # Testament für <autor> aus <repo>
/testament <repo> -list          # Autoren mit Anteilen listen
/testament --help
```
