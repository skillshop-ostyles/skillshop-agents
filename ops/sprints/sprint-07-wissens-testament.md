# Sprint 07 — wissens-testament (/testament)

Regeln: `ops/BIBEL.md` gilt vollständig. Wiederverwendung: Blame-/Log-Muster aus
Sprint 01 (`git-mine.ps1`) darf kopiert/angepasst werden.

## 1. Problem

Wenn ein erfahrener Entwickler geht, geht das Wissen mit: warum Entscheidungen fielen,
wo die Minen liegen, welche "einfachen" Änderungen das System zerlegen. Klassische
Übergabe-Doku scheitert, weil der Gehende nicht weiß, WAS er alles weiß — implizites
Wissen ist per Definition unsichtbar für den Träger. Ein LLM kann aus der Git-Historie
ableiten, WO das Wissen einer Person steckt, und daraus ein gezieltes Interview
generieren, das genau die Fragen stellt, die sonst niemand zu stellen wüsste.

## 2. Nutzen

Vorher: Übergabe = zwei Meetings + ein veraltetes Wiki. Nachher: strukturiertes
Testament mit Entscheidungen, Fallen und Tribal Knowledge, verlinkt auf Code — in
2-3 Interview-Stunden extrahiert statt in Monaten schmerzhaft wiederentdeckt.
Profiteure: Team, Nachfolger, der Gehende selbst (auch für Sabbaticals/Teamwechsel,
nicht nur Kündigungen — und präventiv als "lebendes Testament").

## 3. Scope / Nicht-Scope

**Scope:** Ownership-Mining pro Autor (Blame-Verteilung, Hotspots, Alleinwissen),
daraus generiertes dynamisches Interview mit dem User (der Wissensträger sitzt vor
der Tastatur oder der User stellt die Fragen weiter), strukturiertes testament.md.
**Nicht-Scope:** Keine Bewertung von Personen (kein "Performance-Review" — nur
Wissens-Landkarte). Keine automatischen Mails/Exporte. Read-only gegenüber dem Repo.

## 4. Skill-Spezifikation

Ordner: `wissens-testament/`

Frontmatter:

```yaml
---
name: wissens-testament
description: "Knowledge testament: mines git blame/log to map where one developer's exclusive knowledge lives (sole-author hotspots, high-churn areas they own), generates a targeted interview asking exactly the questions nobody would know to ask, and writes a structured, code-linked testament document. Read-only towards the repo. Trigger: /testament"
trigger: /testament
---
```

Invocation-Steps:

1. `--help` → Usage, stopp.
2. Klären: `-ProjectDir` + Autor (Name/E-Mail wie in Git; `scripts/ownership.ps1
   -ListAuthors` zeigt Kandidaten). Bestätigen.
3. `scripts/ownership.ps1` für den Autor ausführen.
4. Interview gemäß § 6 führen (interaktiv, blockweise, jederzeit pausierbar —
   Zwischenstand wird bei Pause sofort als testament-draft.md gesichert).
5. `testament-<autor>.md` ins Arbeitsverzeichnis schreiben (NICHT ins Repo),
   Kurz-Zusammenfassung geben.

Usage:

```
/testament                       # interaktiv
/testament <repo> <autor>        # Testament für <autor> aus <repo>
/testament <repo> -list          # Autoren mit Anteilen listen
/testament --help
```

## 5. Collector-Skripte

### scripts/ownership.ps1

Parameter: `-ProjectDir` (Pflicht), `-Author` (Pflicht außer bei `-ListAuthors`),
`-ListAuthors` (Switch), `-Extensions`/`-Exclude` (Defaults wie Sprint 03),
`-TopN` (Default 30).

Read-only. Bei `-ListAuthors`: `git shortlog -sne --all` → Autorenliste mit
Commit-Zahlen, fertig.

Sonst, für den Autor:

1. **Blame-Anteile**: pro Quelldatei Zeilenanteil des Autors
   (`git blame --line-porcelain`, aggregiert). Dateien mit Anteil ≥ 60 % =
   "Alleinbesitz-Kandidat".
2. **Commit-Hotspots**: Dateien nach Anzahl Commits des Autors
   (`git log --author=<a> --name-only`).
3. **Exklusivität**: Alleinbesitz-Dateien, die außer dem Autor max. 1 weiterer
   Mensch je angefasst hat = "kritisches Alleinwissen".
4. **Charakteristische Commits**: die 15 größten/meistreferenzierten Commits des
   Autors (Hash, Datum, Subject, betroffene Datei-Anzahl) als Interview-Anker.

JSON-Schema (Beispiel):

```json
{
  "author": "Jane Doe <jane@x.y>",
  "soleOwnership": [ { "file": "src/core/scheduler.ts", "blameShare": 0.92, "otherAuthors": 1 } ],
  "hotspots": [ { "file": "src/core/scheduler.ts", "commits": 47 } ],
  "criticalExclusive": [ "src/core/scheduler.ts" ],
  "anchorCommits": [ { "hash": "abc123", "date": "2021-05-01", "subject": "rewrite retry logic", "filesTouched": 12 } ]
}
```

Fehlerverhalten: Autor ohne Commits → Meldung + Autorenliste als Hilfe, exit 1.
Blame über viele Dateien ist teuer: auf `-TopN` Dateien (nach Commit-Zahl des Autors
vorgefiltert) begrenzen, Ausweis in Zusammenfassung.

## 6. LLM-Analyse-Steps (Interview-Protokoll)

1. Aus dem JSON eine **Wissens-Landkarte** bauen: Bereiche, Exklusivitäts-Grad,
   Interview-Priorität (kritisches Alleinwissen zuerst).
2. **Interview blockweise** führen, pro Block max. 3 Fragen, dann Antworten
   reflektieren (eine Zeile) und nachfassen. Fragen-Typen, immer mit konkretem
   Anker aus der Evidenz:
   - Entscheidung: "Du hast `scheduler.ts` zu 92 % geschrieben (47 Commits). Commit
     abc123 war ein Rewrite der Retry-Logik — was war am ersten Ansatz falsch?"
   - Falle: "Was passiert, wenn jemand X 'vereinfacht'? Wo bricht es zuerst?"
   - Kontext: "Welche externe Randbedingung (Kunde, Deadline, Alt-System) erklärt Y?"
   - Übergabe: "Was sollte dein Nachfolger in Woche 1 an dieser Stelle NICHT anfassen?"
3. Antworten sofort strukturieren; bei jedem Block den Draft aktualisieren
   (Pausierbarkeit, § 4 Step 4).
4. **testament.md-Struktur**: Wissens-Landkarte (Tabelle: Bereich, Exklusivität,
   Risiko) → pro Bereich: Entscheidungen (mit Commit-Belegen), Fallen (wörtlich aus
   dem Interview, mit Datei-Links), Kontextwissen → "Woche-1-Warnliste" für
   Nachfolger → Offene Punkte (nicht gestellte/unbeantwortete Fragen — das Testament
   ist ehrlich über seine Lücken).
5. Evidenz-Regel angepasst: Interview-Aussagen sind als solche gekennzeichnet
   (Quelle: Interview, Datum) — sie brauchen keinen Commit-Beleg, aber jeden
   Code-Bezug als `Datei:Zeile`/Commit verlinken, wo möglich.

## 7. Edge-Cases

| Fall | Verhalten |
|---|---|
| Autor mit mehreren Git-Identitäten | -ListAuthors zeigt Duplikate; SKILL.md: User wählt alle zugehörigen, ownership.ps1 akzeptiert mehrere -Author-Werte |
| Wissensträger nicht verfügbar | Interview-Fragen trotzdem generieren und als Fragenkatalog ausgeben ("Testament in Abwesenheit" — reduzierter Modus, klar gekennzeichnet) |
| Riesiges Repo | TopN-Vorfilter (§ 5); Blame-Laufzeit im Report ausweisen |
| Autor = User selbst | Normalfall (Selbst-Testament) — Fragen in 2. Person stellen, funktioniert identisch |
| Squash-Merge-Historie (Blame zeigt Merger) | Hinweis im Report, dass Blame-Anteile durch Squash verzerrt sein können |
| Kein Git | exit 1, Skill nicht anwendbar |

## 8. Testplan

Smoke (AGENTS-Repo):

```powershell
& .\wissens-testament\scripts\ownership.ps1 -ProjectDir "C:\Users\ostol\Desktop\AGENTS" -ListAuthors
& .\wissens-testament\scripts\ownership.ps1 -ProjectDir "C:\Users\ostol\Desktop\AGENTS" -Author "omcstolz-svg"
```

Erwartung: Autorenliste zeigt omcstolz-svg; Ownership-Lauf: 100 % Blame-Anteile,
alle Dateien als Alleinbesitz, JSON valide, exit 0.

Akzeptanz (dreamzzz-api): `-ListAuthors`, dann Ownership für den Top-Autor.
Erwartung: plausible Anteile (Stichprobe: 2 Dateien manuell per `git blame`
gegenprüfen). Interview-Teil: 3 generierte Fragen prüfen — jede muss einen konkreten
Evidenz-Anker (Datei/Commit) enthalten, keine generischen Fragen ("Was ist wichtig?"
ist ein Fail).

Negativ: unbekannter Autor → exit 1 mit Autorenliste; ungültiger Pfad → exit != 0.

## 9. DoD-Checkliste

- [ ] SKILL.md vollständig inkl. Pausierbarkeit + Abwesenheits-Modus
- [ ] ownership.ps1 (ListAuthors, Blame-Aggregation, Exklusivität, Anker-Commits, TopN)
- [ ] Smoke bestanden (beide Aufrufe, JSON validiert)
- [ ] Akzeptanz dokumentiert (Blame-Stichproben + Fragen-Qualitätsprüfung)
- [ ] Negativ-Tests bestanden
- [ ] testament.md-Struktur erfüllt § 6.4 (inkl. ehrlicher Lücken-Abschnitt)
- [ ] tracking.md aktualisiert, Commit `sprint-07: wissens-testament implementiert`
